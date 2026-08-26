/**
 * EH Home — Production MQTT Protocol Engine (Phase 6)
 *
 * Hardware-independent C module for MQTT message envelope handling.
 *
 * Responsibilities:
 *   - Command validation (deviceId, channelIndex, action, expiresAt, idempotencyKey)
 *   - Command idempotency (deviceId + idempotencyKey ring buffer, size EH_MQTT_IDEM_RING_SIZE)
 *   - Receipt envelope generation (APPLIED, FAILED, EXPIRED, OVERRIDDEN)
 *   - DeviceState / DeviceEvent envelope serialization
 *   - EnergyTelemetry envelope serialization (fixed-point unsigned integers)
 *   - Availability message: "ONLINE" or "OFFLINE" (string, retained, QoS 1)
 *   - Topic building: eh/v1/devices/{deviceId}/{category}
 *
 * IMPORTANT:
 *   - This module NEVER touches GPIO directly
 *   - After command validation, control passes to capability/actuator abstraction layer
 *   - HAL is invoked only through the abstraction layer
 *
 * QoS / Retain Policy:
 *   commands:          QoS 1, retain false  (subscribed by device)
 *   command-receipts:  QoS 1, retain false  (published by device)
 *   state:             QoS 1, retain false  (published by device)
 *   events:            QoS 1, retain false  (published by device)
 *   telemetry:         QoS 0, retain false  (published by device)
 *   availability:      QoS 1, retain true   (published by device, LWT = "OFFLINE")
 */

#ifndef EH_MQTT_PROTOCOL_H
#define EH_MQTT_PROTOCOL_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ========================================================================
 * Constants
 * ======================================================================== */

#define EH_MQTT_TOPIC_MAX_LEN    128  /* eh/v1/devices/{uuid}/{category}\0 */
#define EH_MQTT_PAYLOAD_MAX_LEN  2048 /* Maximum serialized JSON payload */
#define EH_MQTT_UUID_LEN         36   /* Canonical UUID string: 8-4-4-4-12 */
#define EH_MQTT_IDEM_RING_SIZE   32   /* Idempotency ring buffer entries */
#define EH_MQTT_IDEM_KEY_MAX_LEN 64   /* Maximum idempotency key string */

/* Availability constants */
#define EH_MQTT_AVAIL_ONLINE  "ONLINE"
#define EH_MQTT_AVAIL_OFFLINE "OFFLINE"

/* Topic category strings */
#define EH_MQTT_CAT_COMMANDS   "commands"
#define EH_MQTT_CAT_RECEIPTS   "command-receipts"
#define EH_MQTT_CAT_STATE      "state"
#define EH_MQTT_CAT_EVENTS     "events"
#define EH_MQTT_CAT_TELEMETRY  "telemetry"
#define EH_MQTT_CAT_AVAIL      "availability"

/* ========================================================================
 * Error Codes
 * ======================================================================== */

typedef enum {
    EH_MQTT_OK                = 0,
    EH_MQTT_ERR_NULL_ARG      = -1,
    EH_MQTT_ERR_BUFFER_TOO_SMALL = -2,
    EH_MQTT_ERR_INVALID_UUID  = -3,
    EH_MQTT_ERR_INVALID_CMD   = -4,
    EH_MQTT_ERR_EXPIRED       = -5,
    EH_MQTT_ERR_DUPLICATE     = -6,  /* Idempotency hit */
    EH_MQTT_ERR_UNKNOWN_ACTION = -7,
    EH_MQTT_ERR_CHANNEL_RANGE = -8,
    EH_MQTT_ERR_JSON           = -9,
} eh_mqtt_err_t;

/* ========================================================================
 * Command Receipt Status
 * ======================================================================== */

typedef enum {
    EH_MQTT_RECEIPT_APPLIED    = 0,
    EH_MQTT_RECEIPT_FAILED     = 1,
    EH_MQTT_RECEIPT_EXPIRED    = 2,
    EH_MQTT_RECEIPT_OVERRIDDEN = 3,
} eh_mqtt_receipt_status_t;

/* ========================================================================
 * Validated Command Struct
 * ======================================================================== */

typedef struct {
    char     command_id[EH_MQTT_UUID_LEN + 1];
    char     device_id[EH_MQTT_UUID_LEN + 1];
    uint8_t  channel_index;       /* 1-16 */
    char     action[32];          /* e.g., "setPower" */
    bool     params_power;        /* setPower value (if applicable) */
    int32_t  params_level;        /* 0-100 for setLevel (if applicable) */
    char     idempotency_key[EH_MQTT_IDEM_KEY_MAX_LEN];
    int64_t  expires_at_unix_ms;  /* 0 = no expiry */
    char     source[16];          /* APP, AUTOMATION, SCENE */
} eh_mqtt_command_t;

/* ========================================================================
 * Idempotency Ring Buffer Entry
 * ======================================================================== */

typedef struct {
    char device_id[EH_MQTT_UUID_LEN + 1];
    char idem_key[EH_MQTT_IDEM_KEY_MAX_LEN];
    bool active;
} eh_mqtt_idem_entry_t;

/* ========================================================================
 * Idempotency Context (static allocation, no heap)
 * ======================================================================== */

typedef struct {
    eh_mqtt_idem_entry_t entries[EH_MQTT_IDEM_RING_SIZE];
    uint8_t write_idx;
} eh_mqtt_idem_ctx_t;

/* ========================================================================
 * API Declarations
 * ======================================================================== */

/**
 * Build a canonical MQTT topic string.
 *
 * @param device_id  Canonical UUID string (36 chars)
 * @param category   One of EH_MQTT_CAT_* constants
 * @param out_topic  Output buffer
 * @param out_len    Output buffer length (must be >= EH_MQTT_TOPIC_MAX_LEN)
 * @return EH_MQTT_OK on success, error code on failure
 */
eh_mqtt_err_t eh_mqtt_build_topic(
    const char *device_id,
    const char *category,
    char       *out_topic,
    size_t      out_len
);

/**
 * Validate a canonical UUID format string.
 *
 * @param uuid  Input UUID string
 * @return true if valid (8-4-4-4-12 lowercase hex with hyphens), false otherwise
 */
bool eh_mqtt_validate_uuid(const char *uuid);

/**
 * Initialize idempotency ring buffer context.
 *
 * @param ctx  Pointer to eh_mqtt_idem_ctx_t (caller allocates, static recommended)
 */
void eh_mqtt_idem_init(eh_mqtt_idem_ctx_t *ctx);

/**
 * Check if a command is a duplicate (idempotent replay).
 *
 * @param ctx        Idempotency context
 * @param device_id  Device UUID string
 * @param idem_key   Idempotency key string
 * @return true if duplicate (already seen), false if new
 */
bool eh_mqtt_idem_check(eh_mqtt_idem_ctx_t *ctx, const char *device_id, const char *idem_key);

/**
 * Record a new command into the idempotency ring buffer.
 * Must be called only after the command is successfully applied.
 *
 * @param ctx        Idempotency context
 * @param device_id  Device UUID string
 * @param idem_key   Idempotency key string
 */
void eh_mqtt_idem_record(eh_mqtt_idem_ctx_t *ctx, const char *device_id, const char *idem_key);

/**
 * Parse and validate an incoming JSON command payload.
 *
 * Validates:
 *   - commandId UUID format
 *   - deviceId UUID format matches this_device_id
 *   - channelIndex range [1, max_channels]
 *   - action is a recognized value
 *   - idempotencyKey non-empty
 *   - expiresAt not already expired (against current_unix_ms)
 *
 * Does NOT check idempotency — call eh_mqtt_idem_check separately.
 *
 * @param json_payload     Raw JSON string from MQTT message
 * @param payload_len      Length of json_payload
 * @param this_device_id   This device's canonical UUID string
 * @param max_channels     Hardware channel count (1-16)
 * @param current_unix_ms  Current time in Unix milliseconds
 * @param out_cmd          Output: validated command struct
 * @return EH_MQTT_OK or error code
 */
eh_mqtt_err_t eh_mqtt_parse_command(
    const char     *json_payload,
    size_t          payload_len,
    const char     *this_device_id,
    uint8_t         max_channels,
    int64_t         current_unix_ms,
    eh_mqtt_command_t *out_cmd
);

/**
 * Serialize a CommandReceipt JSON payload.
 *
 * @param command_id     commandId of the original command
 * @param device_id      This device's UUID string
 * @param channel_index  Channel that was actuated
 * @param status         Receipt status
 * @param failure_reason Failure reason string (NULL if APPLIED/OVERRIDDEN)
 * @param out_buf        Output buffer
 * @param out_len        Output buffer length
 * @return EH_MQTT_OK or EH_MQTT_ERR_BUFFER_TOO_SMALL
 */
eh_mqtt_err_t eh_mqtt_serialize_receipt(
    const char              *command_id,
    const char              *device_id,
    uint8_t                  channel_index,
    eh_mqtt_receipt_status_t status,
    const char              *failure_reason,
    char                    *out_buf,
    size_t                   out_len
);

/**
 * Serialize a DeviceState JSON payload (all channels).
 *
 * @param device_id      Device UUID string
 * @param channels       Array of per-channel state (power bool)
 * @param num_channels   Number of channels
 * @param out_buf        Output buffer
 * @param out_len        Output buffer length
 * @return EH_MQTT_OK or EH_MQTT_ERR_BUFFER_TOO_SMALL
 */
eh_mqtt_err_t eh_mqtt_serialize_state(
    const char *device_id,
    const bool *channels_power,
    uint8_t     num_channels,
    char       *out_buf,
    size_t      out_len
);

/**
 * Serialize a DeviceEvent JSON payload.
 *
 * @param event_id       Unique event UUID string
 * @param device_id      Device UUID string
 * @param channel_index  Channel that generated the event (1-16)
 * @param event_type     e.g., "switch.changed"
 * @param source         "PHYSICAL_SWITCH" | "CLOUD"
 * @param power          New power state
 * @param seq_number     Monotonic sequence number
 * @param out_buf        Output buffer
 * @param out_len        Output buffer length
 * @return EH_MQTT_OK or EH_MQTT_ERR_BUFFER_TOO_SMALL
 */
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
);

/**
 * Serialize an EnergyTelemetry JSON payload.
 * All measurements are fixed-point unsigned integers.
 *
 * @param device_id      Device UUID string
 * @param channel_index  Measurement channel (1-16)
 * @param v_mv           Voltage in millivolts (unsigned)
 * @param i_ma           Current in milliamps (unsigned)
 * @param p_mw           Active power in milliwatts (unsigned)
 * @param e_tot_wh       Cumulative energy in Wh (unsigned, monotonic)
 * @param e_int_mwh      Interval energy in mWh (unsigned)
 * @param freq_mhz       AC frequency in mHz (unsigned, typically 49500-50500)
 * @param pf_x1000       Power factor × 1000 (unsigned, 0-1000)
 * @param flags          Status flags bitmask
 * @param seq_number     Monotonic sequence number
 * @param out_buf        Output buffer
 * @param out_len        Output buffer length
 * @return EH_MQTT_OK or EH_MQTT_ERR_BUFFER_TOO_SMALL
 */
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
);

/**
 * Build the ONLINE availability payload (static, no allocation needed).
 * @return Pointer to static string "ONLINE"
 */
const char *eh_mqtt_avail_online(void);

/**
 * Build the OFFLINE / LWT payload (static, no allocation needed).
 * @return Pointer to static string "OFFLINE"
 */
const char *eh_mqtt_avail_offline(void);

#ifdef __cplusplus
}
#endif

#endif /* EH_MQTT_PROTOCOL_H */
