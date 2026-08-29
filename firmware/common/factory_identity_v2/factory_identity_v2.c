#include "factory_identity_v2.h"

#include <stdio.h>
#include <string.h>
#include "esp_err.h"
#include "esp_log.h"
#include "esp_random.h"
#include "nvs.h"

#define FACTORY_V2_NAMESPACE "fact_v2"
#define KEY_DEVICE_ID "dev_id"
#define KEY_SERIAL "serial"
#define KEY_COMM_SECRET "comm_sec"
#define KEY_COMM_CONSUMED "comm_cons"
#define KEY_CERT_FP "cert_fp"
#define KEY_IS_DEV "is_dev"

static const char *TAG = "factory_identity_v2";
static factory_identity_v2_t s_identity;

static void generate_canonical_uuid(char *out_uuid, size_t len)
{
    uint8_t b[16];
    esp_fill_random(b, sizeof(b));
    // Set UUID v4 variant/version bits
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;

    snprintf(out_uuid, len,
             "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
             b[0], b[1], b[2], b[3],
             b[4], b[5],
             b[6], b[7],
             b[8], b[9],
             b[10], b[11], b[12], b[13], b[14], b[15]);
}

esp_err_t factory_identity_v2_init(void)
{
    memset(&s_identity, 0, sizeof(s_identity));
    nvs_handle_t handle;
    esp_err_t err = nvs_open(FACTORY_V2_NAMESPACE, NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to open NVS namespace %s: %s", FACTORY_V2_NAMESPACE, esp_err_to_name(err));
        return err;
    }

    size_t dev_id_len = sizeof(s_identity.device_id);
    size_t serial_len = sizeof(s_identity.serial_number);
    size_t secret_len = sizeof(s_identity.commissioning_secret);
    size_t fp_len = sizeof(s_identity.tls_cert_fingerprint);
    uint8_t consumed = 0;
    uint8_t is_dev = 1;

    err = nvs_get_str(handle, KEY_DEVICE_ID, s_identity.device_id, &dev_id_len);
    if (err == ESP_OK) {
        nvs_get_str(handle, KEY_SERIAL, s_identity.serial_number, &serial_len);
        nvs_get_blob(handle, KEY_COMM_SECRET, s_identity.commissioning_secret, &secret_len);
        nvs_get_u8(handle, KEY_COMM_CONSUMED, &consumed);
        nvs_get_str(handle, KEY_CERT_FP, s_identity.tls_cert_fingerprint, &fp_len);
        nvs_get_u8(handle, KEY_IS_DEV, &is_dev);
    } else {
        // Provision new development defaults if factory partition is blank
        generate_canonical_uuid(s_identity.device_id, sizeof(s_identity.device_id));
        snprintf(s_identity.serial_number, sizeof(s_identity.serial_number), "EH-SW3X-2026W12-00001");
        esp_fill_random(s_identity.commissioning_secret, sizeof(s_identity.commissioning_secret));
        s_identity.commissioning_secret_consumed = false;
        snprintf(s_identity.tls_cert_fingerprint, sizeof(s_identity.tls_cert_fingerprint),
                 "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90");
        s_identity.is_development = true;

        nvs_set_str(handle, KEY_DEVICE_ID, s_identity.device_id);
        nvs_set_str(handle, KEY_SERIAL, s_identity.serial_number);
        nvs_set_blob(handle, KEY_COMM_SECRET, s_identity.commissioning_secret, sizeof(s_identity.commissioning_secret));
        nvs_set_u8(handle, KEY_COMM_CONSUMED, 0);
        nvs_set_str(handle, KEY_CERT_FP, s_identity.tls_cert_fingerprint);
        nvs_set_u8(handle, KEY_IS_DEV, 1);
        nvs_commit(handle);
    }

    s_identity.commissioning_secret_consumed = (consumed != 0);
    s_identity.is_development = (is_dev != 0);
    nvs_close(handle);

    ESP_LOGI(TAG, "Factory Identity v2 loaded. DeviceID: %s, Serial: %s, Consumed: %d",
             s_identity.device_id, s_identity.serial_number, s_identity.commissioning_secret_consumed);

    if (s_identity.is_development && !s_identity.commissioning_secret_consumed) {
        char comm_sec_hex[65];
        for (int i = 0; i < 32; i++) {
            snprintf(comm_sec_hex + i * 2, 3, "%02x", s_identity.commissioning_secret[i]);
        }
        ESP_LOGI(TAG, "DEV_COMMISSIONING_QR: EH1:%s:eh-smart-switch-3x:%s:123456",
                 s_identity.device_id, comm_sec_hex);
    }
    return ESP_OK;
}

const factory_identity_v2_t *factory_identity_v2_get(void)
{
    return &s_identity;
}

esp_err_t factory_identity_v2_set_secret_consumed(bool consumed)
{
    s_identity.commissioning_secret_consumed = consumed;
    nvs_handle_t handle;
    esp_err_t err = nvs_open(FACTORY_V2_NAMESPACE, NVS_READWRITE, &handle);
    if (err == ESP_OK) {
        err = nvs_set_u8(handle, KEY_COMM_CONSUMED, consumed ? 1 : 0);
        if (err == ESP_OK) err = nvs_commit(handle);
        nvs_close(handle);
    }
    return err;
}

esp_err_t factory_identity_v2_factory_reset(void)
{
    // Re-enable commissioning secret on physical factory reset
    return factory_identity_v2_set_secret_consumed(false);
}
