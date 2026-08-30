#include "app_lifecycle.h"
#include "factory_identity_v2.h"
#include "wifi_manager.h"
#include "relay_manager.h"
#include "eh_prov1.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#define TAG "APP_LIFECYCLE"
#else
#define TAG "APP_LIFECYCLE"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

#define MAX_LISTENERS 4

static app_lifecycle_state_t s_current_state = APP_STATE_FACTORY_NEW;
static bool s_commissioned = false;
static app_lifecycle_listener_t s_listeners[MAX_LISTENERS];
static size_t s_listener_count = 0;

static const char* s_state_names[] = {
    "FACTORY_NEW",
    "BLE_COMMISSIONING",
    "WIFI_CONNECTING",
    "MQTT_CONNECTING",
    "ACTIVE",
    "ERROR_RECOVERY"
};

void app_lifecycle_init(void)
{
    s_current_state = APP_STATE_FACTORY_NEW;
    s_commissioned = false;
    s_listener_count = 0;
    memset(s_listeners, 0, sizeof(s_listeners));
    ESP_LOGI(TAG, "Lifecycle initialized to %s", s_state_names[s_current_state]);
}

app_lifecycle_state_t app_lifecycle_get_state(void)
{
    return s_current_state;
}

const char* app_lifecycle_get_state_name(app_lifecycle_state_t state)
{
    if ((size_t)state < sizeof(s_state_names)/sizeof(s_state_names[0])) {
        return s_state_names[state];
    }
    return "UNKNOWN";
}

bool app_lifecycle_set_state(app_lifecycle_state_t new_state)
{
    if (s_current_state == new_state) {
        return true;
    }

    // Valid transition checks
    bool valid = false;
    switch (s_current_state) {
        case APP_STATE_FACTORY_NEW:
            valid = (new_state == APP_STATE_BLE_COMMISSIONING || new_state == APP_STATE_WIFI_CONNECTING);
            break;
        case APP_STATE_BLE_COMMISSIONING:
            valid = (new_state == APP_STATE_WIFI_CONNECTING || new_state == APP_STATE_ERROR_RECOVERY || new_state == APP_STATE_FACTORY_NEW);
            break;
        case APP_STATE_WIFI_CONNECTING:
            valid = (new_state == APP_STATE_MQTT_CONNECTING || new_state == APP_STATE_ERROR_RECOVERY || new_state == APP_STATE_BLE_COMMISSIONING);
            break;
        case APP_STATE_MQTT_CONNECTING:
            valid = (new_state == APP_STATE_ACTIVE || new_state == APP_STATE_ERROR_RECOVERY || new_state == APP_STATE_WIFI_CONNECTING);
            break;
        case APP_STATE_ACTIVE:
            valid = (new_state == APP_STATE_ERROR_RECOVERY || new_state == APP_STATE_WIFI_CONNECTING || new_state == APP_STATE_FACTORY_NEW);
            break;
        case APP_STATE_ERROR_RECOVERY:
            valid = (new_state == APP_STATE_WIFI_CONNECTING || new_state == APP_STATE_BLE_COMMISSIONING || new_state == APP_STATE_FACTORY_NEW);
            break;
        default:
            valid = false;
            break;
    }

    if (!valid) {
        ESP_LOGW(TAG, "Invalid state transition rejected: %s -> %s",
                 app_lifecycle_get_state_name(s_current_state),
                 app_lifecycle_get_state_name(new_state));
        return false;
    }

    app_lifecycle_state_t old_state = s_current_state;
    s_current_state = new_state;
    ESP_LOGI(TAG, "State transition: %s -> %s",
             app_lifecycle_get_state_name(old_state),
             app_lifecycle_get_state_name(new_state));

    for (size_t i = 0; i < s_listener_count; i++) {
        if (s_listeners[i]) {
            s_listeners[i](old_state, new_state);
        }
    }
    return true;
}

void app_lifecycle_register_listener(app_lifecycle_listener_t listener)
{
    if (listener && s_listener_count < MAX_LISTENERS) {
        s_listeners[s_listener_count++] = listener;
    }
}

bool app_lifecycle_is_secret_accessible(void)
{
    // Secret is accessible ONLY when uncommissioned and in initial setup states
    return (!s_commissioned) && (s_current_state == APP_STATE_FACTORY_NEW || s_current_state == APP_STATE_BLE_COMMISSIONING);
}

void app_lifecycle_mark_commissioned(void)
{
    s_commissioned = true;
    ESP_LOGI(TAG, "Device marked commissioned. Secret access locked.");
}

bool app_lifecycle_factory_reset(void)
{
    ESP_LOGI(TAG, "FACTORY_RESET_START");
    ESP_LOGI(TAG, "RUNTIME_RESET_START");

    // 1. Disconnect and stop Wi-Fi
    wifi_manager_disconnect();

    // 2. Clear Wi-Fi credentials key-by-key in NVS
    ESP_LOGI(TAG, "WIFI_CREDENTIALS_CLEAR_START");
    wifi_manager_clear_credentials();
    ESP_LOGI(TAG, "WIFI_CREDENTIALS_CLEARED");

    // 3. Clear consumed flag only if development device
    const factory_identity_v2_t *id = factory_identity_v2_get();
    if (id && id->is_development) {
        factory_identity_v2_factory_reset();
    }
    ESP_LOGI(TAG, "PROVISIONED_STATE_CLEARED");

    // 4. Reset runtime in-memory state
    s_current_state = APP_STATE_FACTORY_NEW;
    s_commissioned = false;
    eh_prov1_init();

    // Set relays to safe OFF
    relay_manager_set_power(1, false, "FACTORY_RESET");
    relay_manager_set_power(2, false, "FACTORY_RESET");
    relay_manager_set_power(3, false, "FACTORY_RESET");
    ESP_LOGI(TAG, "RUNTIME_STATE_CLEARED");

    // 5. Verification
    if (wifi_manager_has_credentials()) {
        ESP_LOGE(TAG, "Verification failed: Wi-Fi credentials still present");
        return false;
    }

    id = factory_identity_v2_get();
    if (!id || strlen(id->device_id) == 0 || strlen(id->serial_number) == 0) {
        ESP_LOGE(TAG, "Verification failed: Factory identity invalid");
        return false;
    }

    ESP_LOGI(TAG, "FACTORY_IDENTITY_VERIFIED");
    ESP_LOGI(TAG, "FACTORY_RESET_COMPLETE");

#ifdef ESP_PLATFORM
    vTaskDelay(pdMS_TO_TICKS(200));
    esp_restart();
#endif

    return true;
}
