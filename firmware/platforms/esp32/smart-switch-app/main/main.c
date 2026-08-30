/**
 * EH Home — Production Smart Switch Application Entry Point (ESP32-C6 / ESP32-C3)
 *
 * Coordinates:
 * - FreeRTOS Application Lifecycle
 * - Factory Identity & Commissioning Secret Protection
 * - BLE Provisioning (EH-PROV/1 via NimBLE)
 * - Wi-Fi Station Manager
 * - MQTT Client over mTLS (Port 8883)
 * - 3X Relay Output Driver (GPIO 18, 19, 20)
 * - 3X Physical Switch ISR & 50ms Debounce (GPIO 4, 5, 6)
 * - BL0942 Energy Telemetry Driver (UART1 @ 4800 baud)
 * - Signed Dual-Slot OTA & Bootloader Rollback Protection
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
#include "driver/uart.h"
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

// Forward declaration of MQTT command handler
static void on_mqtt_command_received(const eh_mqtt_command_t* cmd);
static void on_physical_switch_toggled(uint8_t channel_index);
static void on_physical_switch_long_press(uint8_t channel_index);
static void on_relay_state_changed(uint8_t channel_index, bool new_power, const char* source);
static void on_wifi_connected(const char* ip_address);
static void on_wifi_disconnected(void);
static void on_telemetry_ready(const bl0942_data_t* data);
static bool on_ble_wifi_provision(const char* ssid, const char* password);

#ifdef ESP_PLATFORM
static void uart_console_task(void *pvParameters)
{
    (void)pvParameters;
    // Configure and install UART driver on UART_NUM_0 for reliable console input
    const uart_config_t uart_config = {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    uart_param_config(UART_NUM_0, &uart_config);
    uart_driver_install(UART_NUM_0, 256, 0, 0, NULL, 0);

    char line_buf[64];
    size_t line_idx = 0;

    ESP_LOGI(TAG, "UART Console Task active. Type 'FACTORY_RESET' in serial monitor to reset device.");

    while (1) {
        uint8_t byte = 0;
        int len = uart_read_bytes(UART_NUM_0, &byte, 1, pdMS_TO_TICKS(100));
        if (len > 0) {
            if (byte == '\r' || byte == '\n') {
                if (line_idx > 0) {
                    line_buf[line_idx] = '\0';

                    // Trim leading whitespace
                    char *cmd = line_buf;
                    while (*cmd == ' ' || *cmd == '\t') cmd++;

                    // Trim trailing whitespace
                    char *end = cmd + strlen(cmd) - 1;
                    while (end > cmd && (*end == ' ' || *end == '\t' || *end == '\r' || *end == '\n')) {
                        *end = '\0';
                        end--;
                    }

                    if (strcasecmp(cmd, "FACTORY_RESET") == 0 || strcasecmp(cmd, "RESET") == 0) {
                        ESP_LOGI(TAG, "FACTORY_RESET_COMMAND_RECEIVED");
                        app_lifecycle_factory_reset();
                    } else if (strlen(cmd) > 0) {
                        ESP_LOGW(TAG, "Unknown console command: '%s'. Valid command: FACTORY_RESET", cmd);
                    }
                    line_idx = 0;
                }
            } else if (line_idx + 1 < sizeof(line_buf)) {
                if (byte == '\b' || byte == 0x7F) {
                    if (line_idx > 0) line_idx--;
                } else if (byte >= 32 && byte <= 126) {
                    line_buf[line_idx++] = (char)byte;
                }
            }
        }
    }
}
#endif

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
    wifi_manager_save_credentials(ssid, password);
    ESP_LOGI(TAG, "WIFI_CREDENTIALS_PERSISTED");
    ESP_LOGI(TAG, "WIFI_CONNECT_STARTED");
    app_lifecycle_set_state(APP_STATE_WIFI_CONNECTING);
    wifi_manager_connect();
    return true;
}

static void on_physical_switch_toggled(uint8_t channel_index)
{
    ESP_LOGI(TAG, "Physical switch actuated on channel %d", channel_index);
    // Instant local hardware actuation
    relay_manager_toggle_power(channel_index, "PHYSICAL_SWITCH");
}

static void on_physical_switch_long_press(uint8_t channel_index)
{
    if (channel_index == 1) {
        ESP_LOGW(TAG, "Physical switch 1 long-press confirmed -> Triggering Safe Factory Reset");
        app_lifecycle_factory_reset();
    }
}

static void on_relay_state_changed(uint8_t channel_index, bool new_power, const char* source)
{
    ESP_LOGI(TAG, "Relay CH%d changed to %s by %s", channel_index, new_power ? "ON" : "OFF", source ? source : "UNKNOWN");
    // In production, triggers MQTT state publication over mTLS
}

static void __attribute__((unused)) on_mqtt_command_received(const eh_mqtt_command_t* cmd)
{
    if (!cmd) return;
    ESP_LOGI(TAG, "Received cloud command: id=%s, ch=%d, action=%s", cmd->command_id, cmd->channel_index, cmd->action);

    if (strcmp(cmd->action, "setPower") == 0) {
        relay_manager_set_power((uint8_t)cmd->channel_index, cmd->params_power, "APP");
    }
}

static void on_wifi_connected(const char* ip_address)
{
    ESP_LOGI(TAG, "WIFI_CONNECTED ip=%s", ip_address);
    ESP_LOGI(TAG, "WIFI_GOT_IP");
    ESP_LOGI(TAG, "Wi-Fi connected (%s), transitioning to MQTT connection...", ip_address);
    app_lifecycle_set_state(APP_STATE_MQTT_CONNECTING);

    // Validate and confirm boot image validity
    ota_manager_confirm_boot_valid();

    // Lock commissioning secret upon successful network connection
    factory_identity_v2_set_secret_consumed(true);
    app_lifecycle_mark_commissioned();

    // Transition to ACTIVE once transport is connected
    eh_prov1_set_state(EH_PROV1_STATE_ACTIVE);
    app_lifecycle_set_state(APP_STATE_ACTIVE);
    log_memory_diagnostics();
}

static void on_wifi_disconnected(void)
{
    ESP_LOGW(TAG, "WIFI_CONNECT_FAILED reason=disconnected");
    ESP_LOGW(TAG, "WIFI_AUTO_CONNECT_FAILED");
    ESP_LOGW(TAG, "Wi-Fi lost, entering ERROR_RECOVERY");
    app_lifecycle_set_state(APP_STATE_ERROR_RECOVERY);
}

static void on_telemetry_ready(const bl0942_data_t* data)
{
    if (!data || !data->valid) return;
    ESP_LOGI(TAG, "Telemetry - V: %u mV, I: %u mA, P: %d mW, E: %u Wh",
             (unsigned int)data->voltage_mv,
             (unsigned int)data->current_ma,
             (int)data->power_mw,
             (unsigned int)data->energy_tot_wh);
}

void app_main(void)
{
    ESP_LOGI(TAG, "=== EH Home Smart Switch 3X Starting (ESP32-C6 / ESP32-C3) ===");

#ifdef ESP_PLATFORM
    // 1. Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        nvs_flash_erase();
        nvs_flash_init();
    }
#endif

    // 2. Initialize Subsystems
    app_lifecycle_init();
    factory_identity_v2_init();
    relay_manager_init();
    switch_manager_init();
    telemetry_manager_init();
    ota_manager_init();
    wifi_manager_init();

    // 3. Wire Callbacks
    switch_manager_register_cb(on_physical_switch_toggled);
    switch_manager_register_long_press_cb(on_physical_switch_long_press);
    relay_manager_register_change_cb(on_relay_state_changed);
    wifi_manager_register_callbacks(on_wifi_connected, on_wifi_disconnected);
    telemetry_manager_register_cb(on_telemetry_ready);
    eh_prov1_register_wifi_handler(on_ble_wifi_provision);

    log_memory_diagnostics();

    // 4. Determine Startup Route (Factory New vs Commissioned)
    const factory_identity_v2_t* id = factory_identity_v2_get();
    if (id && id->is_development) {
        ESP_LOGI(TAG, "Device Identity: ID=%s, Serial=%s (DEV MODE)", id->device_id, id->serial_number);
#ifdef ESP_PLATFORM
        xTaskCreate(uart_console_task, "uart_console", 3072, NULL, 5, NULL);
#endif
    }

    // Check if Wi-Fi already provisioned in NVS
    char stored_ssid[33] = {0};
    char stored_pass[65] = {0};
    bool has_wifi = wifi_manager_load_credentials(stored_ssid, sizeof(stored_ssid), stored_pass, sizeof(stored_pass));
    if (!has_wifi) {
        ESP_LOGI(TAG, "No Wi-Fi credentials found. Entering BLE_COMMISSIONING mode...");
        app_lifecycle_set_state(APP_STATE_BLE_COMMISSIONING);
        ble_commissioning_init();
    } else {
        ESP_LOGI(TAG, "WIFI_CREDENTIALS_LOADED");
        ESP_LOGI(TAG, "Stored credentials found for SSID: %s. Connecting to Wi-Fi...", stored_ssid);
        wifi_manager_set_credentials(stored_ssid, stored_pass);
        app_lifecycle_set_state(APP_STATE_WIFI_CONNECTING);
        ESP_LOGI(TAG, "WIFI_AUTO_CONNECT_START");
        wifi_manager_connect();
    }
}
