#include "node_protocol.h"

#include <stdbool.h>
#include <stdio.h>
#include "esp_log.h"
#include "nvs.h"

#include "node_actuator.h"

#define NVS_NAMESPACE "node"
#define NVS_STATE_KEY "state"

static const char *TAG = "node_protocol";
static node_state_t s_state = NODE_STATE_FACTORY_NEW;

static bool is_valid_state(uint8_t value)
{
    return value <= NODE_STATE_RETRYING;
}

static void persist_state(void)
{
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &handle);
    if (err == ESP_OK) {
        err = nvs_set_u8(handle, NVS_STATE_KEY, (uint8_t)s_state);
        if (err == ESP_OK) err = nvs_commit(handle);
        nvs_close(handle);
    }
    if (err != ESP_OK) ESP_LOGE(TAG, "Could not persist state: %s", esp_err_to_name(err));
}

void node_protocol_init(void)
{
    nvs_handle_t handle;
    uint8_t stored_state = NODE_STATE_FACTORY_NEW;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READONLY, &handle);
    if (err == ESP_OK) {
        err = nvs_get_u8(handle, NVS_STATE_KEY, &stored_state);
        nvs_close(handle);
    }
    if (err == ESP_OK && is_valid_state(stored_state)) s_state = (node_state_t)stored_state;
    ESP_LOGI(TAG, "Loaded device state: %d", s_state);
}

node_state_t node_protocol_state(void)
{
    return s_state;
}

void node_protocol_set_state(node_state_t state)
{
    if (!is_valid_state((uint8_t)state) || state == s_state) return;
    s_state = state;
    persist_state();
    ESP_LOGI(TAG, "Device state: %d", s_state);
}

size_t node_protocol_make_telemetry(char *buffer, size_t buffer_size)
{
    /* {"v":1,"s":0,"m":0} is 19 bytes and fits a default ATT payload. */
    int length = snprintf(buffer, buffer_size, "{\"v\":1,\"s\":%d,\"m\":%d}",
                          s_state, node_actuator_mist_maker_is_on() ? 1 : 0);
    return length > 0 ? (size_t)length : 0;
}

size_t node_protocol_make_provisioning_status(char *buffer, size_t buffer_size)
{
    int length = snprintf(buffer, buffer_size, "{\"s\":%d}", s_state);
    return length > 0 ? (size_t)length : 0;
}

esp_err_t node_protocol_handle_command(const uint8_t *data, size_t length)
{
    (void)data;
    (void)length;
    return ESP_ERR_NOT_SUPPORTED;
}

esp_err_t node_protocol_handle_provisioning(const uint8_t *data, size_t length)
{
    (void)data;
    (void)length;
    return ESP_ERR_NOT_SUPPORTED;
}
