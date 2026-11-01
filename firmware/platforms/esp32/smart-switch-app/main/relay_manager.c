#include "relay_manager.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "driver/gpio.h"
#include "nvs_flash.h"
#include "nvs.h"
#define TAG "RELAY_MGR"
#define NVS_RELAY_NAMESPACE "relay_state"
#else
#define TAG "RELAY_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static const int s_relay_gpios[EH_RELAY_CHANNEL_COUNT] = {
    GPIO_RELAY_CH1,
#if EH_RELAY_CHANNEL_COUNT >= 2
    GPIO_RELAY_CH2,
#endif
#if EH_RELAY_CHANNEL_COUNT >= 3
    GPIO_RELAY_CH3,
#endif
#if EH_RELAY_CHANNEL_COUNT >= 4
    GPIO_RELAY_CH4,
#endif
};

static const char* s_nvs_keys[EH_RELAY_CHANNEL_COUNT] = {
    "ch1_state",
#if EH_RELAY_CHANNEL_COUNT >= 2
    "ch2_state",
#endif
#if EH_RELAY_CHANNEL_COUNT >= 3
    "ch3_state",
#endif
#if EH_RELAY_CHANNEL_COUNT >= 4
    "ch4_state",
#endif
};

static bool s_relay_states[EH_RELAY_CHANNEL_COUNT] = { false };
static relay_state_change_cb_t s_change_cb = NULL;

#ifdef ESP_PLATFORM
static void save_channel_state_nvs(uint8_t channel_index, bool power)
{
    if (channel_index < 1 || channel_index > EH_RELAY_CHANNEL_COUNT) return;
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_RELAY_NAMESPACE, NVS_READWRITE, &handle);
    if (err == ESP_OK) {
        nvs_set_u8(handle, s_nvs_keys[channel_index - 1], power ? 1 : 0);
        nvs_commit(handle);
        nvs_close(handle);
    } else {
        ESP_LOGW(TAG, "Failed to open NVS to save CH%d state (err=0x%x)", channel_index, err);
    }
}
#endif

void relay_manager_init(void)
{
#ifdef ESP_PLATFORM
    // 1. Read persisted relay states across power loss / reboot first
    nvs_handle_t handle;
    bool has_nvs = (nvs_open(NVS_RELAY_NAMESPACE, NVS_READONLY, &handle) == ESP_OK);

    uint64_t pin_mask = 0;
    for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        uint8_t val = 0;
        if (has_nvs && nvs_get_u8(handle, s_nvs_keys[i], &val) == ESP_OK) {
            s_relay_states[i] = (val != 0);
        } else {
            s_relay_states[i] = false;
        }
        pin_mask |= (1ULL << s_relay_gpios[i]);
        gpio_set_level((gpio_num_t)s_relay_gpios[i], EH_RELAY_POWER_TO_LEVEL(s_relay_states[i]));
    }

    if (has_nvs) {
        nvs_close(handle);
    }

    // 2. Glitch-Free Zero-Chatter Pre-Bias Sequence for every relay pin
    for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        gpio_num_t pin = (gpio_num_t)s_relay_gpios[i];
        int target_level = EH_RELAY_POWER_TO_LEVEL(s_relay_states[i]);

        // Step 1: Explicitly reset pin to disconnect default peripherals (e.g. U0RTS on GPIO 22)
        // and connect IO MUX function to PIN_FUNC_GPIO
        gpio_reset_pin(pin);

        // Step 2: Pre-bias pin to safe inactive level using internal pull resistor
        gpio_set_pull_mode(pin, EH_RELAY_ACTIVE_LEVEL ? GPIO_PULLDOWN_ONLY : GPIO_PULLUP_ONLY);

        // Step 3: Pre-latch output register to target initial level BEFORE enabling output driver
        gpio_set_level(pin, target_level);

        // Step 4: Configure as output with glitch-free characteristics
        gpio_config_t io_conf = {
            .pin_bit_mask = (1ULL << pin),
            .mode = GPIO_MODE_OUTPUT,
            .pull_up_en = EH_RELAY_ACTIVE_LEVEL ? GPIO_PULLUP_DISABLE : GPIO_PULLUP_ENABLE,
            .pull_down_en = EH_RELAY_ACTIVE_LEVEL ? GPIO_PULLDOWN_ENABLE : GPIO_PULLDOWN_DISABLE,
            .intr_type = GPIO_INTR_DISABLE,
        };
        gpio_config(&io_conf);
        gpio_set_direction(pin, GPIO_MODE_OUTPUT);

        // Step 5: Assert target level and configure maximum drive capability (40mA) for opto/transistor relay inputs
        gpio_set_level(pin, target_level);
        gpio_set_drive_capability(pin, GPIO_DRIVE_CAP_3);

        ESP_LOGI(TAG, "Configured Relay CH%d on GPIO %d (initial level=%d, drive=CAP_3)",
                 i + 1, (int)pin, target_level);
    }
#else
    for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        s_relay_states[i] = false;
    }
#endif
    ESP_LOGI(TAG, "Relays initialized - %d channels active", EH_RELAY_CHANNEL_COUNT);
}

void relay_manager_clear_persisted_states(void)
{
#ifdef ESP_PLATFORM
    nvs_handle_t handle;
    if (nvs_open(NVS_RELAY_NAMESPACE, NVS_READWRITE, &handle) == ESP_OK) {
        nvs_erase_all(handle);
        nvs_commit(handle);
        nvs_close(handle);
        ESP_LOGI(TAG, "Persisted relay states erased from NVS");
    }
#endif
}

bool relay_manager_set_power(uint8_t channel_index, bool power, const char* source)
{
    if (channel_index < 1 || channel_index > EH_RELAY_CHANNEL_COUNT) {
        ESP_LOGE(TAG, "Invalid channel index: %d", channel_index);
        return false;
    }

    uint8_t idx = channel_index - 1;
    if (s_relay_states[idx] == power) {
        return true; // No change needed
    }

    s_relay_states[idx] = power;
#ifdef ESP_PLATFORM
    gpio_num_t pin = (gpio_num_t)s_relay_gpios[idx];
    int lvl = EH_RELAY_POWER_TO_LEVEL(power);
    esp_err_t err = gpio_set_level(pin, lvl);
    save_channel_state_nvs(channel_index, power);
    ESP_LOGI(TAG, "CH%d (GPIO %d) power set to %s (lvl=%d, err=0x%x, source: %s, persisted in NVS)",
             channel_index, (int)pin, power ? "ON" : "OFF", lvl, (unsigned int)err, source ? source : "UNKNOWN");
#else
    ESP_LOGI(TAG, "CH%d power set to %s (source: %s)", channel_index, power ? "ON" : "OFF", source ? source : "UNKNOWN");
#endif

    if (s_change_cb) {
        s_change_cb(channel_index, power, source);
    }
    return true;
}

bool relay_manager_toggle_power(uint8_t channel_index, const char* source)
{
    if (channel_index < 1 || channel_index > EH_RELAY_CHANNEL_COUNT) {
        return false;
    }
    uint8_t idx = channel_index - 1;
    return relay_manager_set_power(channel_index, !s_relay_states[idx], source);
}

bool relay_manager_get_power(uint8_t channel_index)
{
    if (channel_index < 1 || channel_index > EH_RELAY_CHANNEL_COUNT) {
        return false;
    }
    return s_relay_states[channel_index - 1];
}

void relay_manager_register_change_cb(relay_state_change_cb_t cb)
{
    s_change_cb = cb;
}
