#include "factory_identity_v2.h"

#include <stdio.h>
#include <string.h>
#include <ctype.h>
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

static char s_override_prod_type[32] = {0};
static char s_override_variant[16] = {0};

void factory_identity_v2_set_product_meta(const char *product_type, const char *variant)
{
    if (product_type && product_type[0]) {
        strncpy(s_override_prod_type, product_type, sizeof(s_override_prod_type) - 1);
        s_override_prod_type[sizeof(s_override_prod_type) - 1] = '\0';
    }
    if (variant && variant[0]) {
        strncpy(s_override_variant, variant, sizeof(s_override_variant) - 1);
        s_override_variant[sizeof(s_override_variant) - 1] = '\0';
    }
}

static const char *get_active_prod_type(void)
{
    return s_override_prod_type[0] ? s_override_prod_type : EH_PRODUCT_TYPE;
}

static const char *get_active_variant(void)
{
    return s_override_variant[0] ? s_override_variant : EH_PRODUCT_VARIANT;
}

const char *factory_identity_v2_get_variant(void)
{
    return get_active_variant();
}

const char *factory_identity_v2_get_product_type(void)
{
    return get_active_prod_type();
}

static bool is_socket_product(void)
{
    const char *pt = get_active_prod_type();
    return (strcmp(pt, "SMART_SOCKET") == 0 || strcmp(pt, "socket") == 0 || strstr(pt, "SOCKET") != NULL);
}

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

#ifdef ESP_PLATFORM
#include "esp_mac.h"
#endif

#ifndef EH_PRODUCT_TYPE
#define EH_PRODUCT_TYPE "SMART_SWITCH"
#endif

#ifndef EH_PRODUCT_VARIANT
#define EH_PRODUCT_VARIANT "4X"
#endif

static void generate_dynamic_serial(char *out_serial, size_t len)
{
    uint8_t mac[6] = {0};
#ifdef ESP_PLATFORM
    esp_err_t m_err = esp_read_mac(mac, ESP_MAC_WIFI_STA);
    if (m_err != ESP_OK) {
        esp_fill_random(mac, sizeof(mac));
    }
#else
    esp_fill_random(mac, sizeof(mac));
#endif
    const char *prefix = is_socket_product() ? "EH-SK" : "EH-SW";
    snprintf(out_serial, len, "%s%s-%02X%02X%02X", prefix, get_active_variant(), mac[3], mac[4], mac[5]);
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

        // Check if stored serial matches current flashed product type and variant
        const char *expected_prefix = is_socket_product() ? "EH-SK" : "EH-SW";
        char expected_tag[32];
        snprintf(expected_tag, sizeof(expected_tag), "%s%s", expected_prefix, get_active_variant());

        if (strstr(s_identity.serial_number, expected_tag) == NULL ||
            strstr(s_identity.serial_number, "2026W12-00001") != NULL ||
            strlen(s_identity.serial_number) == 0) {
            ESP_LOGI(TAG, "Serial number tag mismatch with running firmware (%s vs %s). Regenerating serial...",
                     s_identity.serial_number, expected_tag);
            generate_dynamic_serial(s_identity.serial_number, sizeof(s_identity.serial_number));
            nvs_set_str(handle, KEY_SERIAL, s_identity.serial_number);
            nvs_commit(handle);
        }
    } else {
        // Provision new development defaults if factory partition is blank
        generate_canonical_uuid(s_identity.device_id, sizeof(s_identity.device_id));
        generate_dynamic_serial(s_identity.serial_number, sizeof(s_identity.serial_number));
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
        char var_lower[16];
        const char *v = get_active_variant();
        strncpy(var_lower, v, sizeof(var_lower) - 1);
        var_lower[sizeof(var_lower) - 1] = '\0';
        for (int i = 0; var_lower[i]; i++) {
            var_lower[i] = tolower((unsigned char)var_lower[i]);
        }
        char qr_sku[64];
        snprintf(qr_sku, sizeof(qr_sku), is_socket_product() ? "eh-smart-socket-%s" : "eh-smart-switch-%s", var_lower);
        ESP_LOGI(TAG, "DEV_COMMISSIONING_QR: EH1:%s:%s:%s:123456",
                 s_identity.device_id, qr_sku, comm_sec_hex);
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
