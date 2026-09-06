/**
 * EH Home — Production Smart Switch Application Entry Point (ESP32-C6 / ESP32-C3)
 *
 * Coordinates:
 * - FreeRTOS Application Lifecycle
 * - Factory Identity & Commissioning Secret Protection (fact_v2)
 * - BLE Provisioning (EH-PROV/1 via NimBLE)
 * - Wi-Fi Station Manager with NVS Credential Persistence
 * - MQTT Client over mTLS (Port 8883) with Canonical Topic Taxonomy
 * - 3X Relay Output Driver (GPIO 18, 19, 20) with Local Physical Switch Authority
 * - 3X Physical Switch ISR & 50ms Debounce (GPIO 4, 5, 6)
 * - BL0942 Energy Telemetry Driver (UART1 @ 4800 baud) & Fixed-Point MQTT Publication
 * - Signed Dual-Slot HTTPS OTA with Anti-Rollback & Bootloader Verification
 */

#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_system.h"
#include "esp_heap_caps.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#define TAG "MAIN_APP"
#else
#define TAG "MAIN_APP"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

#include "app_lifecycle.h"
#include "relay_manager.h"
#include "switch_manager.h"
#include "wifi_manager.h"
#include "telemetry_manager.h"
#include "ota_manager.h"
#include "factory_identity_v2.h"
#include "ble_commissioning.h"
#include "eh_prov1.h"
#include "mqtt_protocol.h"
#include "esp_mqtt_client_wrapper.h"

#ifndef CONFIG_EH_MQTT_BROKER_URI
#define CONFIG_EH_MQTT_BROKER_URI "mqtts://mqtt.ehhome.io:8883"
#endif

static eh_mqtt_client_t* s_mqtt_client = NULL;
static eh_mqtt_config_t s_mqtt_config;
static uint32_t s_event_seq = 0;
static uint32_t s_telemetry_seq = 0;

// Forward declarations
static void on_mqtt_command_received(const eh_mqtt_command_t* cmd, void* user_ctx);
static void on_mqtt_connected(void* user_ctx);
static void on_mqtt_disconnected(void* user_ctx);
static void on_physical_switch_toggled(uint8_t channel_index);
static void on_relay_state_changed(uint8_t channel_index, bool new_power, const char* source);
static void on_wifi_connected(const char* ip_address);
static void on_wifi_disconnected(void);
static void on_telemetry_ready(const bl0942_data_t* data);
static bool on_ble_wifi_provision(const char* ssid, const char* password);

static void log_memory_diagnostics(void)
{
#ifdef ESP_PLATFORM
    size_t free_heap = esp_get_free_heap_size();
    size_t min_free_heap = esp_get_minimum_free_heap_size();
    ESP_LOGI(TAG, "Heap Diagnostics - Free: %u bytes, Min Free: %u bytes",
             (unsigned int)free_heap, (unsigned int)min_free_heap);
#endif
}

static bool on_ble_wifi_provision(const char* ssid, const char* password)
{
    ESP_LOGI(TAG, "WIFI_CREDENTIALS_ACCEPTED");
    if (!wifi_manager_set_credentials(ssid, password)) {
        ESP_LOGE(TAG, "WIFI_CONNECT_FAILED reason=invalid_credentials");
        return false;
    }
    ESP_LOGI(TAG, "WIFI_CONNECT_STARTED");
    app_lifecycle_set_state(APP_STATE_WIFI_CONNECTING);
    wifi_manager_connect();
    return true;
}

static void on_physical_switch_toggled(uint8_t channel_index)
{
    ESP_LOGI(TAG, "Physical switch actuated on channel %d", channel_index);
    // Instant local hardware actuation — physical switch has absolute local authority
    relay_manager_toggle_power(channel_index, "PHYSICAL_SWITCH");
}

static void on_relay_state_changed(uint8_t channel_index, bool new_power, const char* source)
{
    ESP_LOGI(TAG, "Relay CH%d changed to %s by %s", channel_index, new_power ? "ON" : "OFF", source ? source : "UNKNOWN");

    if (s_mqtt_client && eh_mqtt_client_is_connected(s_mqtt_client)) {
        // 1. Publish authoritative multi-channel state
        bool powers[EH_RELAY_CHANNEL_COUNT];
        for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
            powers[i] = relay_manager_get_power((uint8_t)(i + 1));
        }
        eh_mqtt_publish_state(s_mqtt_client, powers, EH_RELAY_CHANNEL_COUNT);

        // 2. If actuated by physical switch, emit a switch.changed DeviceEvent
        if (source && strcmp(source, "PHYSICAL_SWITCH") == 0) {
            char event_id[37];
            const factory_identity_v2_t* id = factory_identity_v2_get();
            snprintf(event_id, sizeof(event_id), "evt-%08lx-%04x", (unsigned long)s_event_seq, (unsigned int)channel_index);
            eh_mqtt_publish_event(s_mqtt_client, event_id, channel_index, "switch.changed", "PHYSICAL_SWITCH", new_power, ++s_event_seq);
            (void)id;
        }
    }
}

static void on_mqtt_command_received(const eh_mqtt_command_t* cmd, void* user_ctx)
{
    (void)user_ctx;
    if (!cmd) return;

    ESP_LOGI(TAG, "Received cloud command: id=%s, ch=%d, action=%s", cmd->command_id, cmd->channel_index, cmd->action);

    // Validate channel boundary
    if (cmd->channel_index < 1 || cmd->channel_index > EH_RELAY_CHANNEL_COUNT) {
        ESP_LOGE(TAG, "Command %s rejected: invalid channel index %d", cmd->command_id, cmd->channel_index);
        if (s_mqtt_client) {
            eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                                    EH_MQTT_RECEIPT_FAILED, "Invalid channel index");
        }
        return;
    }

    // Execute supported actions
    if (strcmp(cmd->action, "setPower") == 0) {
        bool ok = relay_manager_set_power((uint8_t)cmd->channel_index, cmd->params_power, "APP");
        if (ok && s_mqtt_client) {
            eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                                    EH_MQTT_RECEIPT_APPLIED, NULL);
        } else if (s_mqtt_client) {
            eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                                    EH_MQTT_RECEIPT_FAILED, "Relay actuation error");
        }
    } else {
        ESP_LOGW(TAG, "Unsupported command action: %s", cmd->action);
        if (s_mqtt_client) {
            eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                                    EH_MQTT_RECEIPT_FAILED, "Unsupported command action");
        }
    }
}

static void on_mqtt_connected(void* user_ctx)
{
    (void)user_ctx;
    ESP_LOGI(TAG, "MQTT broker connected successfully over mTLS");

    // Transition to ACTIVE state now that transport and broker are verified
    eh_prov1_set_state(EH_PROV1_STATE_ACTIVE);
    app_lifecycle_mark_commissioned();
    app_lifecycle_set_state(APP_STATE_ACTIVE);

    // Confirm running firmware image validity (cancels automatic rollback)
    ota_manager_confirm_boot_valid();

    // Publish initial authoritative multi-channel relay state
    bool powers[EH_RELAY_CHANNEL_COUNT];
    for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        powers[i] = relay_manager_get_power((uint8_t)(i + 1));
    }
    eh_mqtt_publish_state(s_mqtt_client, powers, EH_RELAY_CHANNEL_COUNT);

    log_memory_diagnostics();
}

static void on_mqtt_disconnected(void* user_ctx)
{
    (void)user_ctx;
    ESP_LOGW(TAG, "MQTT broker disconnected. Local control (relays & physical switches) remains ACTIVE");
    // Main lifecycle remains in error recovery or active local operation
    // Reconnection is handled automatically with exponential backoff
}

static void on_wifi_connected(const char* ip_address)
{
    ESP_LOGI(TAG, "WIFI_CONNECTED ip=%s", ip_address);
    ESP_LOGI(TAG, "Wi-Fi connected (%s), initializing secure MQTT mTLS client...", ip_address);
    app_lifecycle_set_state(APP_STATE_MQTT_CONNECTING);

    const factory_identity_v2_t* id = factory_identity_v2_get();
    if (!id) {
        ESP_LOGE(TAG, "Factory identity unavailable. Cannot start MQTT client.");
        app_lifecycle_set_state(APP_STATE_ERROR_RECOVERY);
        return;
    }

    if (!s_mqtt_client) {
        memset(&s_mqtt_config, 0, sizeof(s_mqtt_config));
        s_mqtt_config.broker_uri = CONFIG_EH_MQTT_BROKER_URI;
        s_mqtt_config.device_id = id->device_id;
        s_mqtt_config.channel_count = EH_RELAY_CHANNEL_COUNT;
        s_mqtt_config.on_command = on_mqtt_command_received;
        s_mqtt_config.on_connected = on_mqtt_connected;
        s_mqtt_config.on_disconnected = on_mqtt_disconnected;
        s_mqtt_config.user_ctx = NULL;

        if (eh_mqtt_client_start(&s_mqtt_config, &s_mqtt_client) != 0) {
            ESP_LOGE(TAG, "Failed to start MQTT client wrapper");
            app_lifecycle_set_state(APP_STATE_ERROR_RECOVERY);
        }
    }
}

static void on_wifi_disconnected(void)
{
    ESP_LOGW(TAG, "WIFI_CONNECT_FAILED reason=disconnected");
    ESP_LOGW(TAG, "Wi-Fi lost, entering ERROR_RECOVERY (local control active)");
    app_lifecycle_set_state(APP_STATE_ERROR_RECOVERY);
}

static void on_telemetry_ready(const bl0942_data_t* data)
{
    if (!data || !data->valid) return;
    ESP_LOGI(TAG, "Telemetry - V: %u mV, I: %u mA, P: %d mW, E: %u Wh, F: %u mHz",
             (unsigned int)data->voltage_mv,
             (unsigned int)data->current_ma,
             (int)data->power_mw,
             (unsigned int)data->energy_tot_wh,
             (unsigned int)data->frequency_mhz);

    if (s_mqtt_client && eh_mqtt_client_is_connected(s_mqtt_client)) {
        uint32_t p_mw = (uint32_t)(data->power_mw > 0 ? data->power_mw : 0);
        eh_mqtt_publish_telemetry(
            s_mqtt_client,
            1, // Primary energy measurement channel
            data->voltage_mv,
            data->current_ma,
            p_mw,
            data->energy_tot_wh,
            0, // Interval mWh
            data->frequency_mhz,
            1000, // Power factor * 1000
            0,    // Status flags
            ++s_telemetry_seq
        );
    }
}

void app_main(void)
{
    ESP_LOGI(TAG, "=== EH Home Smart Switch 3X Starting (ESP32-C6 / ESP32-C3) ===");

#ifdef ESP_PLATFORM
    // 1. Initialize NVS Flash
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        nvs_flash_erase();
        nvs_flash_init();
    }
#endif

    // 2. Initialize Core Subsystems
    app_lifecycle_init();
    factory_identity_v2_init();
    relay_manager_init();
    switch_manager_init();
    telemetry_manager_init();
    ota_manager_init();
    wifi_manager_init();

    // 3. Wire Callback Dispatchers
    switch_manager_register_cb(on_physical_switch_toggled);
    relay_manager_register_change_cb(on_relay_state_changed);
    wifi_manager_register_callbacks(on_wifi_connected, on_wifi_disconnected);
    telemetry_manager_register_cb(on_telemetry_ready);
    eh_prov1_register_wifi_handler(on_ble_wifi_provision);

    log_memory_diagnostics();

    // 4. Log Device Identity
    const factory_identity_v2_t* id = factory_identity_v2_get();
    if (id) {
        ESP_LOGI(TAG, "Device Identity: ID=%s, Serial=%s (DEV=%d)",
                 id->device_id, id->serial_number, id->is_development);
    }

    // 5. Deterministic Startup Route: Check for Persisted NVS Wi-Fi Credentials
    if (!wifi_manager_has_credentials()) {
        ESP_LOGI(TAG, "No Wi-Fi credentials found in NVS. Entering BLE_COMMISSIONING mode...");
        app_lifecycle_set_state(APP_STATE_BLE_COMMISSIONING);
        ble_commissioning_init();
    } else {
        ESP_LOGI(TAG, "Stored NVS Wi-Fi credentials found. Transitioning to WIFI_CONNECTING...");
        app_lifecycle_set_state(APP_STATE_WIFI_CONNECTING);
        wifi_manager_connect();
    }
}
