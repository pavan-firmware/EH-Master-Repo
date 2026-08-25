/**
 * EH Home — ESP32 MQTT Client Wrapper (Phase 6)
 *
 * ESP-IDF esp-mqtt component wrapper for production TLS MQTT connectivity.
 *
 * Architecture:
 *   MQTT Command arrives
 *     │
 *     ▼
 *   esp_mqtt_client (TLS, port 8883)
 *     │
 *     ▼
 *   eh_mqtt_parse_command() [mqtt_protocol.h]
 *     │ (validates, checks expiry, checks idempotency)
 *     ▼
 *   Capability / Actuator Abstraction Layer
 *     │
 *     ▼
 *   Hardware HAL (GPIO relay toggle)
 *     │
 *     ▼
 *   eh_mqtt_serialize_receipt() → MQTT publish command-receipt
 *
 * Device MQTT Identity:
 *   - Uses per-device X.509 client certificate (CN = deviceId)
 *   - Provisioned during manufacturing / Phase 5B BLE commissioning
 *   - Private key stored in ESP32 NVS / secure flash partition
 *   - Private key NEVER leaves the device
 *
 * Availability / LWT:
 *   - LWT configured at connect time: topic = eh/v1/devices/{deviceId}/availability
 *     payload = "OFFLINE", QoS = 1, retain = true
 *   - On successful connection: publish "ONLINE" (retained, QoS 1)
 *   - On graceful disconnect: publish "OFFLINE" before disconnect
 *
 * Reconnect Behavior:
 *   - Bounded exponential backoff: initial 1s, max 120s, jitter ±10%
 *   - Reconnect handles: Wi-Fi loss, broker restart, TLS failure,
 *     certificate failure, auth failure, subscription failure
 *   - On reconnect: re-subscribe, publish state, publish availability ONLINE
 *   - Stale commands from before disconnect are NOT replayed
 *
 * ACL:
 *   - SUBSCRIBE: eh/v1/devices/{deviceId}/commands only
 *   - PUBLISH: eh/v1/devices/{deviceId}/{receipts,state,events,telemetry,availability}
 *
 * NOTE: This module never manipulates GPIO directly.
 */

#ifndef EH_ESP32_MQTT_CLIENT_WRAPPER_H
#define EH_ESP32_MQTT_CLIENT_WRAPPER_H

#include <stdint.h>
#include <stdbool.h>
#include "mqtt_protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ========================================================================
 * Configuration
 * ======================================================================== */

#define EH_MQTT_RECONNECT_INITIAL_MS   1000   /* 1 second initial backoff */
#define EH_MQTT_RECONNECT_MAX_MS     120000   /* 120 second max backoff */
#define EH_MQTT_KEEPALIVE_SEC            60   /* MQTT keepalive interval */
#define EH_MQTT_LWT_QOS                   1
#define EH_MQTT_LWT_RETAIN             true

typedef struct {
    const char *broker_uri;          /* "mqtts://{host}:8883" */
    const char *device_id;           /* Canonical UUID string (CN of cert) */
    const char *client_cert_pem;     /* PEM-encoded device client certificate */
    const char *client_key_pem;      /* PEM-encoded device private key (flash-stored) */
    const char *ca_cert_pem;         /* PEM-encoded EH Device CA certificate */
    uint8_t     channel_count;       /* Number of physical channels (1-4) */

    /* Callbacks */
    void (*on_command)(const eh_mqtt_command_t *cmd, void *user_ctx);
    void (*on_connected)(void *user_ctx);
    void (*on_disconnected)(void *user_ctx);
    void *user_ctx;
} eh_mqtt_config_t;

/* ========================================================================
 * Client Handle
 * ======================================================================== */

typedef struct eh_mqtt_client_s eh_mqtt_client_t;

/* ========================================================================
 * API
 * ======================================================================== */

/**
 * Initialize and start the MQTT client.
 *
 * Configures LWT (last will) before connecting so the broker can automatically
 * publish "OFFLINE" (retained) if the device disconnects unexpectedly.
 *
 * @param config  Non-null pointer to configuration struct (lifetime must exceed client)
 * @param out_client  Output: allocated client handle
 * @return 0 on success, -1 on failure
 */
int eh_mqtt_client_start(const eh_mqtt_config_t *config, eh_mqtt_client_t **out_client);

/**
 * Gracefully disconnect and destroy the client.
 * Publishes "OFFLINE" (retained) before disconnecting.
 *
 * @param client  Client handle from eh_mqtt_client_start
 */
void eh_mqtt_client_stop(eh_mqtt_client_t *client);

/**
 * Publish command receipt after hardware actuation.
 *
 * @param client        Client handle
 * @param command_id    commandId from the original Command envelope
 * @param channel_index Channel that was actuated
 * @param status        Receipt status
 * @param failure_reason NULL if APPLIED or OVERRIDDEN, else error string
 * @return 0 on success, -1 on publish failure
 */
int eh_mqtt_publish_receipt(
    eh_mqtt_client_t        *client,
    const char              *command_id,
    uint8_t                  channel_index,
    eh_mqtt_receipt_status_t status,
    const char              *failure_reason
);

/**
 * Publish authoritative device state (all channels).
 * Called after successful hardware actuation and on reconnect.
 *
 * @param client        Client handle
 * @param channels_power Boolean array of per-channel power states
 * @param num_channels   Number of channels
 * @return 0 on success, -1 on publish failure
 */
int eh_mqtt_publish_state(
    eh_mqtt_client_t *client,
    const bool       *channels_power,
    uint8_t           num_channels
);

/**
 * Publish a device event.
 * Used for physical switch toggles (source = PHYSICAL_SWITCH) and other events.
 *
 * @param client        Client handle
 * @param event_id      Unique event UUID string
 * @param channel_index Channel index (1-based)
 * @param event_type    e.g., "switch.changed"
 * @param source        "PHYSICAL_SWITCH" | "CLOUD"
 * @param power         New power state
 * @param seq_number    Monotonic sequence number
 * @return 0 on success, -1 on failure
 */
int eh_mqtt_publish_event(
    eh_mqtt_client_t *client,
    const char       *event_id,
    uint8_t           channel_index,
    const char       *event_type,
    const char       *source,
    bool              power,
    uint32_t          seq_number
);

/**
 * Publish energy telemetry (QoS 0, no retain).
 * All measurements are fixed-point unsigned integers.
 *
 * @param client         Client handle
 * @param channel_index  Measurement channel (1-based)
 * @param v_mv           Voltage in millivolts
 * @param i_ma           Current in milliamps
 * @param p_mw           Active power in milliwatts
 * @param e_tot_wh       Cumulative energy in Wh
 * @param e_int_mwh      Interval energy in mWh
 * @param freq_mhz       AC frequency in mHz
 * @param pf_x1000       Power factor × 1000
 * @param flags          Status flags bitmask
 * @param seq_number     Monotonic sequence number
 * @return 0 on success, -1 on failure
 */
int eh_mqtt_publish_telemetry(
    eh_mqtt_client_t *client,
    uint8_t           channel_index,
    uint32_t          v_mv,
    uint32_t          i_ma,
    uint32_t          p_mw,
    uint32_t          e_tot_wh,
    uint32_t          e_int_mwh,
    uint32_t          freq_mhz,
    uint32_t          pf_x1000,
    uint8_t           flags,
    uint32_t          seq_number
);

/**
 * Returns true if the client is currently connected to the broker.
 * @param client  Client handle
 */
bool eh_mqtt_client_is_connected(const eh_mqtt_client_t *client);

#ifdef __cplusplus
}
#endif

#endif /* EH_ESP32_MQTT_CLIENT_WRAPPER_H */
