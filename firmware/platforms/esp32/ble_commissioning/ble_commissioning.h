#pragma once

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t ble_commissioning_init(void);
void ble_commissioning_start_advertising(void);

#ifdef __cplusplus
}
#endif
