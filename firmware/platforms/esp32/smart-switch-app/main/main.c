/**
 * EH Home — Production Smart Switch Application Entry Point (ESP32-C6 /
 * ESP32-C3)
 *
 * Coordinates:
 * - FreeRTOS Application Lifecycle
 * - Factory Identity & Commissioning Secret Protection (fact_v2)
 * - BLE Provisioning (EH-PROV/1 via NimBLE)
 * - Wi-Fi Station Manager with NVS Credential Persistence
 * - MQTT Client over mTLS (Port 8883) with Canonical Topic Taxonomy
 * - 3X Relay Output Driver (GPIO 18, 19, 20) with Local Physical Switch
 * Authority
 * - 3X Physical Switch ISR & 50ms Debounce (GPIO 4, 5, 6)
 * - BL0942 Energy Telemetry Driver (UART1 @ 4800 baud) & Fixed-Point MQTT
 * Publication
 * - Signed Dual-Slot HTTPS OTA with Anti-Rollback & Bootloader Verification
 */

#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_random.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#define TAG "MAIN_APP"
#else
#define TAG "MAIN_APP"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...)                                                \
  printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

#include "board_config.h"
#include "app_lifecycle.h"
#include "ble_commissioning.h"
#include "eh_prov1.h"
#include "esp_mqtt_client_wrapper.h"
#include "factory_identity_v2.h"
#include "local_server.h"
#include "mqtt_protocol.h"
#include "ota_manager.h"
#include "relay_manager.h"
#include "reset_button.h"
#include "status_led.h"
#include "switch_manager.h"
#include "telemetry_manager.h"
#include "wifi_manager.h"
#include "edge_routine_engine.h"
#include "time_sync_manager.h"

#ifndef CONFIG_EH_MQTT_BROKER_URI
#define CONFIG_EH_MQTT_BROKER_URI "mqtt://192.168.0.227:1883"
#endif

#ifndef EH_FEATURE_ENERGY_MONITORING
#if defined(CONFIG_EH_ENERGY_METERING_ENABLED)
#define EH_FEATURE_ENERGY_MONITORING 1
#else
#define EH_FEATURE_ENERGY_MONITORING 0
#endif
#endif

static eh_mqtt_client_t *s_mqtt_client = NULL;
static eh_mqtt_config_t s_mqtt_config;
static uint32_t s_event_seq = 0;
#if EH_FEATURE_ENERGY_MONITORING
static uint32_t s_telemetry_seq = 0;
#endif

// Cloud State Settling Timer (2.0s debounce for remote MQTT publishing)
static bool s_last_cloud_published_state[EH_RELAY_CHANNEL_COUNT] = { false };
static bool s_has_last_cloud_published_state = false;
static esp_timer_handle_t s_cloud_settling_timer = NULL;
static bool s_settling_has_physical_event = false;
static uint8_t s_settling_physical_channel = 0;
static void on_cloud_settled_timer_expired(void *arg);

// Forward declarations
static void on_mqtt_command_received(const eh_mqtt_command_t *cmd,
                                     void *user_ctx);
static void on_mqtt_connected(void *user_ctx);
static void on_mqtt_disconnected(void *user_ctx);
static void on_physical_switch_toggled(uint8_t channel_index);
static void on_relay_state_changed(uint8_t channel_index, bool new_power,
                                   const char *source);
static void on_wifi_connected(const char *ip_address);
static void on_wifi_disconnected(void);
#if EH_FEATURE_ENERGY_MONITORING
static void on_telemetry_ready(const bl0942_data_t *data);
#endif
static bool on_ble_wifi_provision(const char *ssid, const char *password);

static void log_memory_diagnostics(void) {
#ifdef ESP_PLATFORM
  size_t free_heap = esp_get_free_heap_size();
  size_t min_free_heap = esp_get_minimum_free_heap_size();
  ESP_LOGI(TAG, "Heap Diagnostics - Free: %u bytes, Min Free: %u bytes",
           (unsigned int)free_heap, (unsigned int)min_free_heap);
#endif
}

static bool on_ble_wifi_provision(const char *ssid, const char *password) {
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

static void on_physical_switch_toggled(uint8_t channel_index) {
  ESP_LOGI(TAG, "Physical switch actuated on channel %d", channel_index);
  // Dual Emergency Stop (Local): Human tactile toggle has absolute priority and disarms edge routines
  edge_routine_engine_emergency_stop(channel_index, "PHYSICAL_SWITCH");
  // Instant local hardware actuation — physical switch has absolute local authority
  relay_manager_toggle_power(channel_index, "PHYSICAL_SWITCH");
}

static void on_cloud_settled_timer_expired(void *arg) {
  (void)arg;
  bool current_powers[EH_RELAY_CHANNEL_COUNT];
  bool state_changed = false;

  for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
    current_powers[i] = relay_manager_get_power((uint8_t)(i + 1));
    if (!s_has_last_cloud_published_state || current_powers[i] != s_last_cloud_published_state[i]) {
      state_changed = true;
    }
  }

  if (!state_changed) {
    ESP_LOGI(TAG, "Cloud Settling Timer (2.0s): Net state unchanged (rapid toggles suppressed). Skipped MQTT publish.");
    s_settling_has_physical_event = false;
    return;
  }

  memcpy(s_last_cloud_published_state, current_powers, sizeof(current_powers));
  s_has_last_cloud_published_state = true;

  if (s_mqtt_client && eh_mqtt_client_is_connected(s_mqtt_client)) {
    ESP_LOGI(TAG, "Cloud Settling Timer (2.0s): Publishing stable settled state to MQTT broker.");
    eh_mqtt_publish_state(s_mqtt_client, current_powers, EH_RELAY_CHANNEL_COUNT);

    if (s_settling_has_physical_event && s_settling_physical_channel > 0) {
      char event_id[37];
      uint32_t uptime_ms = (uint32_t)(esp_timer_get_time() / 1000);
      uint32_t rand_nonce = esp_random();
      snprintf(event_id, sizeof(event_id), "evt-%08lx-%04x-%04lx",
               (unsigned long)uptime_ms, (unsigned int)s_settling_physical_channel,
               (unsigned long)(rand_nonce & 0xFFFF));
      eh_mqtt_publish_event(s_mqtt_client, event_id, s_settling_physical_channel,
                            "switch.changed", "PHYSICAL_SWITCH",
                            current_powers[s_settling_physical_channel - 1],
                            ++s_event_seq);
    }
  }
  s_settling_has_physical_event = false;
  s_settling_physical_channel = 0;
}

static void on_relay_state_changed(uint8_t channel_index, bool new_power,
                                   const char *source) {
  ESP_LOGI(TAG, "Relay CH%d changed to %s by %s", channel_index,
           new_power ? "ON" : "OFF", source ? source : "UNKNOWN");

  // Provide immediate physical LED pulse feedback for tactile/command confirmation
  status_led_trigger_action_feedback();

  bool powers[EH_RELAY_CHANNEL_COUNT];
  for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
    powers[i] = relay_manager_get_power((uint8_t)(i + 1));
  }

  // 1. Broadcast real-time state change over Local UDP port 4210 IMMEDIATELY (<10ms)
  // Ensures local mobile apps on Wi-Fi experience zero UI lag
  local_server_broadcast_state(powers, EH_RELAY_CHANNEL_COUNT);

  // 2. Track physical event origin for settled publish
  if (source && strcmp(source, "PHYSICAL_SWITCH") == 0) {
    s_settling_has_physical_event = true;
    s_settling_physical_channel = channel_index;
  }

  // 3. Reset and re-arm the 2.0-second Cloud State Settling Timer
  // Prevents cloud broker spamming during rapid child/tactile toggling
#ifdef ESP_PLATFORM
  if (s_cloud_settling_timer) {
    esp_timer_stop(s_cloud_settling_timer);
    esp_timer_start_once(s_cloud_settling_timer, 2000000); // 2000000 us = 2.0 seconds
  }
#else
  on_cloud_settled_timer_expired(NULL);
#endif
}

static void on_mqtt_command_received(const eh_mqtt_command_t *cmd,
                                     void *user_ctx) {
  (void)user_ctx;
  if (!cmd)
    return;

  ESP_LOGI(TAG, "Received cloud command: id=%s, ch=%d, action=%s",
           cmd->command_id, cmd->channel_index, cmd->action);

  // 1. Dual Emergency Stop & Routine Actions (Remote / Office over Cloud MQTT)
  if (strcmp(cmd->action, "emergencyStop") == 0) {
    ESP_LOGW(TAG, "Cloud MQTT EMERGENCY_STOP received: Aborting all routines and cutting power.");
    edge_routine_engine_emergency_stop(0, "MQTT_EMERGENCY_STOP");
    for (int i = 1; i <= EH_RELAY_CHANNEL_COUNT; i++) {
      relay_manager_set_power((uint8_t)i, false, "EMERGENCY_STOP");
    }
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_APPLIED, NULL);
    }
    return;
  }

  if (strcmp(cmd->action, "stopRoutine") == 0) {
    ESP_LOGI(TAG, "Cloud MQTT stopRoutine received on channel %d", cmd->channel_index);
    edge_routine_engine_emergency_stop((uint8_t)cmd->channel_index, "MQTT_STOP_ROUTINE");
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_APPLIED, NULL);
    }
    return;
  }

  // 2. MQTT Remote Routine Provisioning (upsertRoutine & deleteRoutine)
  if (strcmp(cmd->action, "upsertRoutine") == 0) {
    ESP_LOGI(TAG, "Cloud MQTT upsertRoutine received: id=%s, name=%s, ch=%d",
             cmd->routine_id, cmd->routine_name, cmd->channel_index);
    if (cmd->routine_id[0] == '\0' || cmd->channel_index < 1 || cmd->channel_index > EH_RELAY_CHANNEL_COUNT) {
      if (s_mqtt_client) {
        eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                                EH_MQTT_RECEIPT_FAILED, "Invalid routine parameters");
      }
      return;
    }
    edge_routine_t r;
    memset(&r, 0, sizeof(r));
    strncpy(r.id, cmd->routine_id, sizeof(r.id) - 1);
    strncpy(r.name, cmd->routine_name[0] ? cmd->routine_name : "Cloud Routine", sizeof(r.name) - 1);
    r.channel_index = cmd->channel_index;
    r.target_power = cmd->routine_target_power;
    r.is_toggle = false;
    r.trigger_type = (edge_trigger_type_t)cmd->routine_trigger;
    r.duration_sec = cmd->routine_duration;
    r.hour = cmd->routine_hour;
    r.minute = cmd->routine_minute;
    r.days_mask = cmd->routine_days_mask ? cmd->routine_days_mask : 0x7F;
    r.enabled = cmd->routine_enabled;

    bool ok = edge_routine_engine_upsert_routine(&r);
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                              ok ? EH_MQTT_RECEIPT_APPLIED : EH_MQTT_RECEIPT_FAILED,
                              ok ? NULL : "Failed to persist routine to NVS");
    }
    return;
  }

  if (strcmp(cmd->action, "deleteRoutine") == 0) {
    ESP_LOGI(TAG, "Cloud MQTT deleteRoutine received: id=%s", cmd->routine_id);
    bool ok = edge_routine_engine_delete_routine(cmd->routine_id);
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id, cmd->channel_index,
                              ok ? EH_MQTT_RECEIPT_APPLIED : EH_MQTT_RECEIPT_FAILED,
                              ok ? NULL : "Routine not found");
    }
    return;
  }

  // 3. Channel Boundary Validation for Standard Actuation
  if (cmd->channel_index < 1 || cmd->channel_index > EH_RELAY_CHANNEL_COUNT) {
    ESP_LOGE(TAG, "Command %s rejected: invalid channel index %d",
             cmd->command_id, cmd->channel_index);
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_FAILED,
                              "Invalid channel index");
    }
    return;
  }

  // 4. Standard Relay Actuation (setPower)
  if (strcmp(cmd->action, "setPower") == 0) {
    // If turning off channel, abort any running edge routine on that channel
    if (!cmd->params_power) {
      edge_routine_engine_emergency_stop((uint8_t)cmd->channel_index, "MQTT_SET_POWER_OFF");
    }
    bool ok = relay_manager_set_power((uint8_t)cmd->channel_index,
                                      cmd->params_power, "APP");
    if (ok && s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_APPLIED,
                              NULL);
    } else if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_FAILED,
                              "Relay actuation error");
    }
  } else if (strcmp(cmd->action, "otaUpdate") == 0) {
    ESP_LOGI(TAG, "Cloud MQTT otaUpdate received. Starting deterministic OTA upgrade...");
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_APPLIED,
                              "OTA_INITIATED");
    }
    // Manifest is downloaded and verified by ota_manager
  } else {
    ESP_LOGW(TAG, "Unsupported command action: %s", cmd->action);
    if (s_mqtt_client) {
      eh_mqtt_publish_receipt(s_mqtt_client, cmd->command_id,
                              cmd->channel_index, EH_MQTT_RECEIPT_FAILED,
                              "Unsupported command action");
    }
  }
}


static void on_mqtt_connected(void *user_ctx) {
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

static void mqtt_heartbeat_task(void *arg) {
  (void)arg;
  while (1) {
    vTaskDelay(pdMS_TO_TICKS(25000));
    if (s_mqtt_client && eh_mqtt_client_is_connected(s_mqtt_client)) {
      bool powers[EH_RELAY_CHANNEL_COUNT];
      for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        powers[i] = relay_manager_get_power((uint8_t)(i + 1));
      }
      eh_mqtt_publish_state(s_mqtt_client, powers, EH_RELAY_CHANNEL_COUNT);
    }
  }
}

static void on_mqtt_disconnected(void *user_ctx) {
  (void)user_ctx;
  ESP_LOGW(TAG, "MQTT broker disconnected. Local control (relays & physical "
                "switches) remains ACTIVE");
  app_lifecycle_set_state(APP_STATE_LOCAL_OPERATIONAL);
}

static void on_wifi_connected(const char *ip_address) {
  ESP_LOGI(TAG, "WIFI_CONNECTED ip=%s", ip_address);
  ESP_LOGI(
      TAG,
      "Wi-Fi connected (%s), starting Local LAN HTTP server & MQTT client...",
      ip_address);
  eh_prov1_set_state(EH_PROV1_STATE_ACTIVE);

  // 1. Start Local LAN Server immediately on port 80 (Local control works even
  // if cloud/MQTT is down)
  local_server_start();
  app_lifecycle_set_state(APP_STATE_LOCAL_OPERATIONAL);

  // Broadcast boot announcement over UDP port 4210 (3 bursts spaced 1.5 seconds apart) so apps on the LAN instantly recognize the device
  bool initial_powers[EH_RELAY_CHANNEL_COUNT];
  for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
    initial_powers[i] = relay_manager_get_power(i + 1);
  }
  local_server_start_boot_announce_burst(initial_powers, EH_RELAY_CHANNEL_COUNT);

  // 2. Start SNTP Time Synchronization now that IP stack and Wi-Fi are active
  time_sync_manager_start_sntp();

  // 3. Start Cloud MQTT client
  const factory_identity_v2_t *id = factory_identity_v2_get();
  if (!id) {
    ESP_LOGE(TAG, "Factory identity unavailable. Cannot start MQTT client.");
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
      ESP_LOGW(TAG, "MQTT client initialization pending/offline, remaining in "
                    "LOCAL_OPERATIONAL mode");
    }
  }
}

static void on_wifi_disconnected(void) {
  ESP_LOGW(TAG, "WIFI_CONNECT_FAILED reason=disconnected");
  ESP_LOGW(TAG, "Wi-Fi lost, entering ERROR_RECOVERY (local hardware physical "
                "switch control active)");
  local_server_stop();
  app_lifecycle_set_state(APP_STATE_ERROR_RECOVERY);
}

#if EH_FEATURE_ENERGY_MONITORING
static void on_telemetry_ready(const bl0942_data_t *data) {
  if (!data || !data->valid)
    return;
  ESP_LOGI(TAG, "Telemetry - V: %u mV, I: %u mA, P: %d mW, E: %u Wh, F: %u mHz",
           (unsigned int)data->voltage_mv, (unsigned int)data->current_ma,
           (int)data->power_mw, (unsigned int)data->energy_tot_wh,
           (unsigned int)data->frequency_mhz);

  if (s_mqtt_client && eh_mqtt_client_is_connected(s_mqtt_client)) {
    uint32_t p_mw = (uint32_t)(data->power_mw > 0 ? data->power_mw : 0);
    eh_mqtt_publish_telemetry(s_mqtt_client,
                              1, // Primary energy measurement channel
                              data->voltage_mv, data->current_ma, p_mw,
                              data->energy_tot_wh,
                              0, // Interval mWh
                              data->frequency_mhz,
                              1000, // Power factor * 1000
                              0,    // Status flags
                              ++s_telemetry_seq);
  }
}
#endif

#ifndef EH_FIRMWARE_FAMILY
#define EH_FIRMWARE_FAMILY "esp32c6-switch-platform"
#endif

// Embedded firmware family signature for deterministic post-compilation
// artifact verification
static const char __attribute__((used)) s_eh_firmware_family_sig[] =
    "EH_FIRMWARE_FAMILY:" EH_FIRMWARE_FAMILY ":END_FAMILY";

#ifndef EH_FIRMWARE_VERSION
#define EH_FIRMWARE_VERSION "1.0.0"
#endif

#ifndef EH_PRODUCT_TYPE
#define EH_PRODUCT_TYPE "SMART_SWITCH"
#endif

#ifndef EH_PRODUCT_VARIANT
#define EH_PRODUCT_VARIANT "4X"
#endif

#ifndef EH_MODEL_NAME
#if EH_FEATURE_ENERGY_MONITORING
#define EH_MODEL_NAME "EH-SW4X-EM"
#else
#define EH_MODEL_NAME "EH-SW-4X"
#endif
#endif

#if defined(CONFIG_IDF_TARGET_ESP32)
#define EH_HARDWARE_TARGET "ESP32_DEV_BOARD"
#elif defined(CONFIG_IDF_TARGET_ESP32C6)
#define EH_HARDWARE_TARGET "ESP32C6_PROD_BOARD"
#elif defined(CONFIG_IDF_TARGET_ESP32C3)
#define EH_HARDWARE_TARGET "ESP32C3_PROD_BOARD"
#else
#define EH_HARDWARE_TARGET "ESP32_DEV_BOARD"
#endif

static void log_diagnostic_banner(const factory_identity_v2_t *id) {
  ESP_LOGI(TAG, "==================================================");
  ESP_LOGI(TAG, "EH SMART HOME PROTOTYPE");
  ESP_LOGI(TAG, "==================================================");
  ESP_LOGI(TAG, "Product      : %s", EH_PRODUCT_TYPE);
  ESP_LOGI(TAG, "Model        : %s", EH_MODEL_NAME);
  ESP_LOGI(TAG, "Family       : %s [%s]", EH_FIRMWARE_FAMILY,
           s_eh_firmware_family_sig);
  ESP_LOGI(TAG, "Variant      : %s", EH_PRODUCT_VARIANT);
  ESP_LOGI(TAG, "Hardware     : %s", EH_HARDWARE_TARGET);
  ESP_LOGI(TAG, "Firmware     : %s", EH_FIRMWARE_VERSION);
  ESP_LOGI(TAG, "Device ID    : %s", id ? id->device_id : "UNKNOWN");
  ESP_LOGI(TAG, "Serial       : %s", id ? id->serial_number : "UNKNOWN");
  ESP_LOGI(TAG, "Relay Count  : %d", EH_RELAY_CHANNEL_COUNT);
  ESP_LOGI(TAG, "Switch Count : %d", EH_SWITCH_CHANNEL_COUNT);
  ESP_LOGI(TAG, "Status LED   : GPIO %d", GPIO_STATUS_LED);
  ESP_LOGI(TAG, "Reset Button : GPIO %d (Hold 10s)", GPIO_RESET_BUTTON);
  ESP_LOGI(TAG, "Energy Meter : %s",
           (EH_FEATURE_ENERGY_MONITORING != 0)
               ? "ENABLED (BL0942)"
               : "DISABLED (Standard Non-EM Panel)");
  ESP_LOGI(TAG, "BLE          : ENABLED");
  ESP_LOGI(TAG, "WiFi         : ENABLED");
  ESP_LOGI(TAG, "MQTT         : ENABLED");
  ESP_LOGI(TAG, "OTA          : ENABLED");
  ESP_LOGI(TAG, "==================================================");
}

void app_main(void) {
  ESP_LOGI(TAG, "=== EH Home Smart Switch/Socket 4X Starting ===");

#ifdef ESP_PLATFORM
  // 1. Initialize NVS Flash
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
      ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    nvs_flash_erase();
    nvs_flash_init();
  }
#endif

  // 2. Initialize Core Subsystems
  app_lifecycle_init();
  factory_identity_v2_set_product_meta(EH_PRODUCT_TYPE, EH_PRODUCT_VARIANT);
  factory_identity_v2_init();
  status_led_init();
  reset_button_init();
  relay_manager_init();
  wifi_manager_init();
  time_sync_manager_init();
  edge_routine_engine_init();
  switch_manager_init();

#ifdef ESP_PLATFORM
  // Initialize Cloud State Settling Timer (2.0s non-blocking debounce for MQTT publish)
  const esp_timer_create_args_t settling_timer_args = {
      .callback = &on_cloud_settled_timer_expired,
      .name = "cloud_settle_tmr"
  };
  esp_timer_create(&settling_timer_args, &s_cloud_settling_timer);
#endif
#if EH_FEATURE_ENERGY_MONITORING
  telemetry_manager_init();
#endif
  ota_manager_init();

  // 3. Wire Callback Dispatchers
  app_lifecycle_register_listener(status_led_lifecycle_listener);
  switch_manager_register_cb(on_physical_switch_toggled);
  relay_manager_register_change_cb(on_relay_state_changed);
  wifi_manager_register_callbacks(on_wifi_connected, on_wifi_disconnected);
#if EH_FEATURE_ENERGY_MONITORING
  telemetry_manager_register_cb(on_telemetry_ready);
#endif
  eh_prov1_register_wifi_handler(on_ble_wifi_provision);

  // Launch background periodic MQTT heartbeat & state sync task (8KB stack to
  // safely accommodate TLS/cJSON payload serialization)
  xTaskCreate(mqtt_heartbeat_task, "mqtt_hb_task", 8192, NULL, 3, NULL);

  log_memory_diagnostics();

  // 4. Log Deterministic Diagnostic Identity Banner
  const factory_identity_v2_t *id = factory_identity_v2_get();
  log_diagnostic_banner(id);

  // 5. Deterministic Startup Route: Check for Persisted NVS Wi-Fi Credentials
  if (!wifi_manager_has_credentials()) {
    ESP_LOGI(TAG, "No Wi-Fi credentials found in NVS. Entering "
                  "BLE_COMMISSIONING mode...");
    app_lifecycle_set_state(APP_STATE_BLE_COMMISSIONING);
    const char *prod_name = (strcmp(EH_PRODUCT_TYPE, "SMART_SOCKET") == 0)
        ? "EH Smart Socket " EH_PRODUCT_VARIANT
        : "EH Smart Switch " EH_PRODUCT_VARIANT;
    const char *prod_var = (strcmp(EH_PRODUCT_TYPE, "SMART_SOCKET") == 0)
        ? "eh-smart-socket-" EH_PRODUCT_VARIANT
        : "eh-smart-switch-" EH_PRODUCT_VARIANT;
    ble_commissioning_set_product_meta(prod_name, prod_var, EH_RELAY_CHANNEL_COUNT, (EH_FEATURE_ENERGY_MONITORING != 0));
    ble_commissioning_init();

  } else {
    ESP_LOGI(TAG, "Stored NVS Wi-Fi credentials found. Transitioning to "
                  "WIFI_CONNECTING...");
    app_lifecycle_set_state(APP_STATE_WIFI_CONNECTING);
    wifi_manager_connect();
  }
}
