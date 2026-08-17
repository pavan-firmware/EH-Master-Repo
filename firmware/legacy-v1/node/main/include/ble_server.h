#pragma once

#include "esp_err.h"

/* Starts BLE discovery and the read-only Smart Home GATT service. */
esp_err_t ble_server_init(void);
void ble_server_publish_state(void);

