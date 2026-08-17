#include "factory_identity.h"

#include <stdio.h>

#include "esp_err.h"
#include "esp_random.h"
#include "nvs.h"

#include "node_identity.h"

#define FACTORY_NAMESPACE "factory"
#define DEVICE_ID_KEY "device_id"
#define SERIAL_KEY "serial"
#define DEVELOPMENT_KEY "is_dev"

static char s_device_id[37]; /* UUID-like 128-bit identifier, without hyphens. */
static char s_serial_number[32];
static bool s_is_development;

static void generate_device_id(void)
{
    uint8_t bytes[16];
    esp_fill_random(bytes, sizeof(bytes));
    snprintf(s_device_id, sizeof(s_device_id),
             "%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
             bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
             bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
    snprintf(s_serial_number, sizeof(s_serial_number), "SHN-DEV-%s",
             node_identity_ble_name() + 3);
}

void factory_identity_init(void)
{
    nvs_handle_t handle;
    size_t device_id_size = sizeof(s_device_id);
    size_t serial_size = sizeof(s_serial_number);
    uint8_t development = 1;
    esp_err_t err = nvs_open(FACTORY_NAMESPACE, NVS_READWRITE, &handle);
    ESP_ERROR_CHECK(err);

    err = nvs_get_str(handle, DEVICE_ID_KEY, s_device_id, &device_id_size);
    if (err == ESP_OK) err = nvs_get_str(handle, SERIAL_KEY, s_serial_number, &serial_size);
    if (err == ESP_OK) (void)nvs_get_u8(handle, DEVELOPMENT_KEY, &development);

    if (err != ESP_OK) {
        generate_device_id();
        ESP_ERROR_CHECK(nvs_set_str(handle, DEVICE_ID_KEY, s_device_id));
        ESP_ERROR_CHECK(nvs_set_str(handle, SERIAL_KEY, s_serial_number));
        ESP_ERROR_CHECK(nvs_set_u8(handle, DEVELOPMENT_KEY, 1));
        ESP_ERROR_CHECK(nvs_commit(handle));
        development = 1;
    }
    nvs_close(handle);
    s_is_development = development != 0;
}

const char *factory_identity_device_id(void) { return s_device_id; }
const char *factory_identity_serial_number(void) { return s_serial_number; }
bool factory_identity_is_development(void) { return s_is_development; }
