#pragma once

#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"

typedef enum {
    NODE_STATE_FACTORY_NEW = 0,
    NODE_STATE_COMMISSIONING = 1,
    NODE_STATE_PROVISIONED = 2,
    NODE_STATE_ONLINE = 3,
    NODE_STATE_RETRYING = 4,
} node_state_t;

void node_protocol_init(void);
node_state_t node_protocol_state(void);
void node_protocol_set_state(node_state_t state);

/* Compact payload remains below the default 20-byte BLE notification budget. */
size_t node_protocol_make_telemetry(char *buffer, size_t buffer_size);
size_t node_protocol_make_provisioning_status(char *buffer, size_t buffer_size);

/* Reserved for a future authenticated commissioning channel. */
esp_err_t node_protocol_handle_command(const uint8_t *data, size_t length);
esp_err_t node_protocol_handle_provisioning(const uint8_t *data, size_t length);
