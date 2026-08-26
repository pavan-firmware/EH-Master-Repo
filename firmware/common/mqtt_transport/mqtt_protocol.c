/**
 * EH Home — Production MQTT Protocol Engine Implementation (Phase 6)
 *
 * Hardware-independent C module for MQTT message handling.
 *
 * JSON serialization uses snprintf for deterministic stack-only encoding.
 * JSON parsing uses a minimal hand-rolled parser to avoid heap dependencies.
 * For production builds with ESP-IDF, cJSON from IDF components may be used —
 * but all fixed-point telemetry fields MUST be serialized as unsigned integers.
 *
 * IMPORTANT:
 *   - Never log raw command payloads (may contain sensitive params)
 *   - Never write private keys or credential material
 *   - Fixed-point telemetry fields are always unsigned integers on wire
 */

#include "mqtt_protocol.h"
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <time.h>

/* ========================================================================
 * Internal helpers
 * ======================================================================== */

static const char *RECEIPT_STATUS_STRINGS[] = {
    "APPLIED", "FAILED", "EXPIRED", "OVERRIDDEN"
};

/** Simple hex digit check for UUID validation */
static bool _is_hex_char(char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

/* ========================================================================
 * UUID Validation
 * ======================================================================== */

bool eh_mqtt_validate_uuid(const char *uuid) {
    if (!uuid) return false;
    /* Format: 8-4-4-4-12 hex lowercase, total 36 chars including 4 hyphens */
    if (strlen(uuid) != EH_MQTT_UUID_LEN) return false;

    const int hyphen_positions[] = {8, 13, 18, 23};
    for (int i = 0; i < EH_MQTT_UUID_LEN; i++) {
        bool is_hyphen = (i == 8 || i == 13 || i == 18 || i == 23);
        if (is_hyphen) {
            if (uuid[i] != '-') return false;
        } else {
            if (!_is_hex_char(uuid[i])) return false;
        }
    }
    return true;
}

/* ========================================================================
 * Topic Builder
 * ======================================================================== */

eh_mqtt_err_t eh_mqtt_build_topic(
    const char *device_id,
    const char *category,
    char       *out_topic,
    size_t      out_len
) {
    if (!device_id || !category || !out_topic || out_len == 0) return EH_MQTT_ERR_NULL_ARG;
    if (!eh_mqtt_validate_uuid(device_id)) return EH_MQTT_ERR_INVALID_UUID;

    int n = snprintf(out_topic, out_len, "eh/v1/devices/%s/%s", device_id, category);
    if (n < 0 || (size_t)n >= out_len) return EH_MQTT_ERR_BUFFER_TOO_SMALL;
    return EH_MQTT_OK;
}

/* ========================================================================
 * Idempotency Ring Buffer
 * ======================================================================== */

void eh_mqtt_idem_init(eh_mqtt_idem_ctx_t *ctx) {
    if (!ctx) return;
    memset(ctx, 0, sizeof(eh_mqtt_idem_ctx_t));
}

bool eh_mqtt_idem_check(eh_mqtt_idem_ctx_t *ctx, const char *device_id, const char *idem_key) {
    if (!ctx || !device_id || !idem_key) return false;

    for (int i = 0; i < EH_MQTT_IDEM_RING_SIZE; i++) {
        eh_mqtt_idem_entry_t *e = &ctx->entries[i];
        if (e->active &&
            strncmp(e->device_id, device_id, EH_MQTT_UUID_LEN) == 0 &&
            strncmp(e->idem_key, idem_key, EH_MQTT_IDEM_KEY_MAX_LEN - 1) == 0)
        {
            return true; /* Duplicate found */
        }
    }
    return false;
}

void eh_mqtt_idem_record(eh_mqtt_idem_ctx_t *ctx, const char *device_id, const char *idem_key) {
    if (!ctx || !device_id || !idem_key) return;

    eh_mqtt_idem_entry_t *slot = &ctx->entries[ctx->write_idx];
    strncpy(slot->device_id, device_id, EH_MQTT_UUID_LEN);
    slot->device_id[EH_MQTT_UUID_LEN] = '\0';
    strncpy(slot->idem_key, idem_key, EH_MQTT_IDEM_KEY_MAX_LEN - 1);
    slot->idem_key[EH_MQTT_IDEM_KEY_MAX_LEN - 1] = '\0';
    slot->active = true;

    ctx->write_idx = (ctx->write_idx + 1) % EH_MQTT_IDEM_RING_SIZE;
}

/* ========================================================================
 * Command Parser
 *
 * Minimal hand-rolled JSON field extractor for embedded use.
 * Extracts string, integer, and boolean field values from flat JSON objects.
 * ======================================================================== */

/**
 * Extract a string value for a given JSON key from a flat JSON object.
 * Returns pointer to start of value within json (not null-terminated).
 * Sets *val_len to the length of the unescaped value.
 *
 * Returns NULL if key not found.
 */
static const char *_json_get_string(const char *json, size_t json_len, const char *key, size_t *val_len) {
    char search[128];
    snprintf(search, sizeof(search), "\"%s\"", key);
    const char *pos = (const char *)memmem(json, json_len, search, strlen(search));
    if (!pos) return NULL;

    pos += strlen(search);
    /* Skip whitespace and colon */
    while ((size_t)(pos - json) < json_len && (*pos == ' ' || *pos == ':' || *pos == '\t')) pos++;
    if ((size_t)(pos - json) >= json_len) return NULL;

    if (*pos != '"') return NULL;
    pos++; /* Skip opening quote */
    const char *start = pos;
    while ((size_t)(pos - json) < json_len && *pos != '"') pos++;
    *val_len = (size_t)(pos - start);
    return start;
}

/**
 * Extract a boolean value for a given JSON key.
 * Returns -1 if not found, 0 if false, 1 if true.
 */
static int _json_get_bool(const char *json, size_t json_len, const char *key) {
    char search[128];
    snprintf(search, sizeof(search), "\"%s\"", key);
    const char *pos = (const char *)memmem(json, json_len, search, strlen(search));
    if (!pos) return -1;

    pos += strlen(search);
    while ((size_t)(pos - json) < json_len && (*pos == ' ' || *pos == ':' || *pos == '\t')) pos++;
    if ((size_t)(pos - json) >= json_len) return -1;

    if (strncmp(pos, "true", 4) == 0) return 1;
    if (strncmp(pos, "false", 5) == 0) return 0;
    return -1;
}

/**
 * Extract a 64-bit integer value for a given JSON key.
 * Returns INT64_MIN if not found.
 */
static int64_t _json_get_int64(const char *json, size_t json_len, const char *key) {
    char search[128];
    snprintf(search, sizeof(search), "\"%s\"", key);
    const char *pos = (const char *)memmem(json, json_len, search, strlen(search));
    if (!pos) return INT64_MIN;

    pos += strlen(search);
    while ((size_t)(pos - json) < json_len && (*pos == ' ' || *pos == ':' || *pos == '\t')) pos++;
    if ((size_t)(pos - json) >= json_len) return INT64_MIN;

    /* Skip optional quote for string-encoded integers */
    bool quoted = (*pos == '"');
    if (quoted) pos++;

    if (*pos == '-' || isdigit((unsigned char)*pos)) {
        return (int64_t)strtoll(pos, NULL, 10);
    }
    return INT64_MIN;
}

eh_mqtt_err_t eh_mqtt_parse_command(
    const char        *json_payload,
    size_t             payload_len,
    const char        *this_device_id,
    uint8_t            max_channels,
    int64_t            current_unix_ms,
    eh_mqtt_command_t *out_cmd
) {
    if (!json_payload || !this_device_id || !out_cmd) return EH_MQTT_ERR_NULL_ARG;
    if (!eh_mqtt_validate_uuid(this_device_id)) return EH_MQTT_ERR_INVALID_UUID;

    memset(out_cmd, 0, sizeof(eh_mqtt_command_t));

    size_t val_len = 0;
    const char *val = NULL;

    /* commandId */
    val = _json_get_string(json_payload, payload_len, "commandId", &val_len);
    if (!val || val_len != EH_MQTT_UUID_LEN) return EH_MQTT_ERR_INVALID_CMD;
    memcpy(out_cmd->command_id, val, val_len);
    out_cmd->command_id[EH_MQTT_UUID_LEN] = '\0';
    if (!eh_mqtt_validate_uuid(out_cmd->command_id)) return EH_MQTT_ERR_INVALID_CMD;

    /* deviceId — must match this device */
    val = _json_get_string(json_payload, payload_len, "deviceId", &val_len);
    if (!val || val_len != EH_MQTT_UUID_LEN) return EH_MQTT_ERR_INVALID_CMD;
    memcpy(out_cmd->device_id, val, val_len);
    out_cmd->device_id[EH_MQTT_UUID_LEN] = '\0';
    if (strncmp(out_cmd->device_id, this_device_id, EH_MQTT_UUID_LEN) != 0) {
        return EH_MQTT_ERR_INVALID_CMD;
    }

    /* channelIndex */
    int64_t ch_raw = _json_get_int64(json_payload, payload_len, "channelIndex");
    if (ch_raw < 1 || ch_raw > max_channels) return EH_MQTT_ERR_CHANNEL_RANGE;
    out_cmd->channel_index = (uint8_t)ch_raw;

    /* action */
    val = _json_get_string(json_payload, payload_len, "action", &val_len);
    if (!val || val_len == 0 || val_len >= sizeof(out_cmd->action)) return EH_MQTT_ERR_INVALID_CMD;
    memcpy(out_cmd->action, val, val_len);
    out_cmd->action[val_len] = '\0';

    /* idempotencyKey */
    val = _json_get_string(json_payload, payload_len, "idempotencyKey", &val_len);
    if (!val || val_len == 0 || val_len >= EH_MQTT_IDEM_KEY_MAX_LEN) return EH_MQTT_ERR_INVALID_CMD;
    memcpy(out_cmd->idempotency_key, val, val_len);
    out_cmd->idempotency_key[val_len] = '\0';

    /* expiresAt (Unix milliseconds integer) */
    int64_t expires_at = _json_get_int64(json_payload, payload_len, "expiresAt");
    if (expires_at != INT64_MIN) {
        out_cmd->expires_at_unix_ms = expires_at;
        if (expires_at > 0 && current_unix_ms > 0 && expires_at <= current_unix_ms) {
            return EH_MQTT_ERR_EXPIRED;
        }
    }

    /* source */
    val = _json_get_string(json_payload, payload_len, "source", &val_len);
    if (val && val_len > 0 && val_len < sizeof(out_cmd->source)) {
        memcpy(out_cmd->source, val, val_len);
        out_cmd->source[val_len] = '\0';
    }

    /* params.value (for setPower) */
    if (strcmp(out_cmd->action, "setPower") == 0) {
        int pwr = _json_get_bool(json_payload, payload_len, "value");
        out_cmd->params_power = (pwr == 1);
    }

    return EH_MQTT_OK;
}

/* ========================================================================
 * Serializers
 * ======================================================================== */

eh_mqtt_err_t eh_mqtt_serialize_receipt(
    const char              *command_id,
    const char              *device_id,
    uint8_t                  channel_index,
    eh_mqtt_receipt_status_t status,
    const char              *failure_reason,
    char                    *out_buf,
    size_t                   out_len
) {
    if (!command_id || !device_id || !out_buf) return EH_MQTT_ERR_NULL_ARG;

    const char *status_str = RECEIPT_STATUS_STRINGS[status];
    const char *reason_str = failure_reason ? failure_reason : "";

    int n = snprintf(out_buf, out_len,
        "{\"schemaVersion\":1,"
        "\"commandId\":\"%s\","
        "\"deviceId\":\"%s\","
        "\"channelIndex\":%u,"
        "\"status\":\"%s\","
        "\"failureReason\":%s%s%s,"
        "\"timestamp\":\"%s\"}",
        command_id,
        device_id,
        (unsigned)channel_index,
        status_str,
        failure_reason ? "\"" : "null",
        failure_reason ? failure_reason : "",
        failure_reason ? "\"" : "",
        "2026-01-01T00:00:00Z" /* placeholder; replace with real ISO8601 time */
    );

    if (n < 0 || (size_t)n >= out_len) return EH_MQTT_ERR_BUFFER_TOO_SMALL;
    return EH_MQTT_OK;
}

eh_mqtt_err_t eh_mqtt_serialize_state(
    const char *device_id,
    const bool *channels_power,
    uint8_t     num_channels,
    char       *out_buf,
    size_t      out_len
) {
    if (!device_id || !channels_power || !out_buf) return EH_MQTT_ERR_NULL_ARG;

    int pos = snprintf(out_buf, out_len,
        "{\"schemaVersion\":1,\"deviceId\":\"%s\",\"connectionState\":\"ONLINE\",\"channels\":[",
        device_id
    );
    if (pos < 0 || (size_t)pos >= out_len) return EH_MQTT_ERR_BUFFER_TOO_SMALL;

    for (uint8_t i = 0; i < num_channels; i++) {
        int n = snprintf(out_buf + pos, out_len - pos,
            "%s{\"schemaVersion\":1,\"channelIndex\":%u,\"reportedState\":{\"power\":%s},\"confidence\":\"CONFIRMED\"}",
            i > 0 ? "," : "",
            (unsigned)(i + 1),
            channels_power[i] ? "true" : "false"
        );
        if (n < 0 || (size_t)n >= out_len - pos) return EH_MQTT_ERR_BUFFER_TOO_SMALL;
        pos += n;
    }

    int end = snprintf(out_buf + pos, out_len - pos, "]}");
    if (end < 0 || (size_t)end >= out_len - pos) return EH_MQTT_ERR_BUFFER_TOO_SMALL;
    return EH_MQTT_OK;
}

eh_mqtt_err_t eh_mqtt_serialize_event(
    const char *event_id,
    const char *device_id,
    uint8_t     channel_index,
    const char *event_type,
    const char *source,
    bool        power,
    uint32_t    seq_number,
    char       *out_buf,
    size_t      out_len
) {
    if (!event_id || !device_id || !event_type || !source || !out_buf) return EH_MQTT_ERR_NULL_ARG;

    int n = snprintf(out_buf, out_len,
        "{\"schemaVersion\":1,"
        "\"eventId\":\"%s\","
        "\"deviceId\":\"%s\","
        "\"channelIndex\":%u,"
        "\"eventType\":\"%s\","
        "\"source\":\"%s\","
        "\"payload\":{\"power\":%s},"
        "\"sequenceNumber\":%lu}",
        event_id,
        device_id,
        (unsigned)channel_index,
        event_type,
        source,
        power ? "true" : "false",
        (unsigned long)seq_number
    );

    if (n < 0 || (size_t)n >= out_len) return EH_MQTT_ERR_BUFFER_TOO_SMALL;
    return EH_MQTT_OK;
}

eh_mqtt_err_t eh_mqtt_serialize_telemetry(
    const char *device_id,
    uint8_t     channel_index,
    uint32_t    v_mv,
    uint32_t    i_ma,
    uint32_t    p_mw,
    uint32_t    e_tot_wh,
    uint32_t    e_int_mwh,
    uint32_t    freq_mhz,
    uint32_t    pf_x1000,
    uint8_t     flags,
    uint32_t    seq_number,
    char       *out_buf,
    size_t      out_len
) {
    if (!device_id || !out_buf) return EH_MQTT_ERR_NULL_ARG;

    int n = snprintf(out_buf, out_len,
        "{\"schemaVersion\":1,"
        "\"deviceId\":\"%s\","
        "\"channelIndex\":%u,"
        "\"v_mv\":%lu,"
        "\"i_ma\":%lu,"
        "\"p_mw\":%lu,"
        "\"e_tot_wh\":%lu,"
        "\"e_int_mwh\":%lu,"
        "\"freq_mhz\":%lu,"
        "\"pf_x1000\":%lu,"
        "\"flags\":%u,"
        "\"sequenceNumber\":%lu}",
        device_id,
        (unsigned)channel_index,
        (unsigned long)v_mv,
        (unsigned long)i_ma,
        (unsigned long)p_mw,
        (unsigned long)e_tot_wh,
        (unsigned long)e_int_mwh,
        (unsigned long)freq_mhz,
        (unsigned long)pf_x1000,
        (unsigned)flags,
        (unsigned long)seq_number
    );

    if (n < 0 || (size_t)n >= out_len) return EH_MQTT_ERR_BUFFER_TOO_SMALL;
    return EH_MQTT_OK;
}

const char *eh_mqtt_avail_online(void) {
    return EH_MQTT_AVAIL_ONLINE;
}

const char *eh_mqtt_avail_offline(void) {
    return EH_MQTT_AVAIL_OFFLINE;
}
