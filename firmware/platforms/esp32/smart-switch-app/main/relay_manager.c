#include "relay_manager.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "driver/gpio.h"
#define TAG "RELAY_MGR"
#else
#define TAG "RELAY_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static const int s_relay_gpios[EH_RELAY_CHANNEL_COUNT] = {
    GPIO_RELAY_CH1,
    GPIO_RELAY_CH2,
    GPIO_RELAY_CH3
};

static bool s_relay_states[EH_RELAY_CHANNEL_COUNT] = { false, false, false };
static relay_state_change_cb_t s_change_cb = NULL;

void relay_manager_init(void)
{
#ifdef ESP_PLATFORM
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << GPIO_RELAY_CH1) | (1ULL << GPIO_RELAY_CH2) | (1ULL << GPIO_RELAY_CH3),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_ENABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);

    for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        gpio_set_level((gpio_num_t)s_relay_gpios[i], 0);
        s_relay_states[i] = false;
    }
#else
    for (int i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
        s_relay_states[i] = false;
    }
#endif
    ESP_LOGI(TAG, "Relays initialized (CH1: GPIO%d, CH2: GPIO%d, CH3: GPIO%d) - all OFF",
             GPIO_RELAY_CH1, GPIO_RELAY_CH2, GPIO_RELAY_CH3);
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
    gpio_set_level((gpio_num_t)s_relay_gpios[idx], power ? 1 : 0);
#endif

    ESP_LOGI(TAG, "CH%d power set to %s (source: %s)", channel_index, power ? "ON" : "OFF", source ? source : "UNKNOWN");

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
