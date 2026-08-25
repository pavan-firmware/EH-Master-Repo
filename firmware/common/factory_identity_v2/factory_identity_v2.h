#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char device_id[37];            /* Canonical UUID format (with hyphens) */
    char serial_number[32];        /* Manufacturing serial number */
    uint8_t commissioning_secret[32]; /* Raw 32-byte secret */
    bool commissioning_secret_consumed;
    char tls_cert_fingerprint[65]; /* SHA-256 hex string of client cert */
    bool is_development;
} factory_identity_v2_t;

esp_err_t factory_identity_v2_init(void);
const factory_identity_v2_t *factory_identity_v2_get(void);
esp_err_t factory_identity_v2_set_secret_consumed(bool consumed);
esp_err_t factory_identity_v2_factory_reset(void);

#ifdef __cplusplus
}
#endif
