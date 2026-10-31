#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t ble_commissioning_init(void);
void ble_commissioning_start_advertising(void);
void ble_commissioning_set_product_meta(const char *product_name, const char *variant, uint8_t channels, bool energy);

#ifdef __cplusplus
}
#endif
