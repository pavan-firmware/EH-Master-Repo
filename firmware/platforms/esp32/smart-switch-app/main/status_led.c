#include "status_led.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "driver/gpio.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#define TAG "STATUS_LED"
#else
#define TAG "STATUS_LED"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static status_led_pattern_t s_current_pattern = STATUS_LED_OFF;
static bool s_led_level = false;

#ifdef ESP_PLATFORM
static esp_timer_handle_t s_led_timer = NULL;
static esp_timer_handle_t s_action_timer = NULL;
static uint32_t s_cycle_step = 0;
static bool s_action_feedback_active = false;

static void set_physical_led(bool level)
{
    s_led_level = level;
    gpio_set_level((gpio_num_t)GPIO_STATUS_LED, level ? 1 : 0);
}

static void action_timer_callback(void* arg)
{
    (void)arg;
    s_action_feedback_active = false;
    // Restore base pattern level
    if (s_current_pattern == STATUS_LED_SOLID_ON) {
        set_physical_led(true);
    } else if (s_current_pattern == STATUS_LED_OFF) {
        set_physical_led(false);
    }
}

static void led_timer_callback(void* arg)
{
    (void)arg;
    if (s_action_feedback_active) {
        return; // Don't interrupt momentary action flash
    }

    switch (s_current_pattern) {
        case STATUS_LED_OFF:
            set_physical_led(false);
            break;

        case STATUS_LED_SOLID_ON:
            set_physical_led(true);
            break;

        case STATUS_LED_FAST_BLINK:   // 150ms ON / 150ms OFF
        case STATUS_LED_SLOW_BLINK:   // 500ms ON / 500ms OFF
        case STATUS_LED_MEDIUM_BLINK: // 200ms ON / 200ms OFF
        case STATUS_LED_RAPID_BURST:  // 50ms ON / 50ms OFF
        case STATUS_LED_OTA_UPDATING: // 50ms ON / 50ms OFF
            set_physical_led(!s_led_level);
            break;

        case STATUS_LED_HEARTBEAT: // 100ms ON, 2.4s OFF (25 steps @ 100ms)
            s_cycle_step = (s_cycle_step + 1) % 25;
            set_physical_led(s_cycle_step == 0);
            break;

        case STATUS_LED_DOUBLE_BLINK: // Step 0: ON, 1: OFF, 2: ON, 3..17: OFF (18 steps @ 100ms = 1.8s)
            s_cycle_step = (s_cycle_step + 1) % 18;
            set_physical_led(s_cycle_step == 0 || s_cycle_step == 2);
            break;

        default:
            set_physical_led(false);
            break;
    }
}
#endif

void status_led_init(void)
{
#ifdef ESP_PLATFORM
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << GPIO_STATUS_LED),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);
    gpio_set_level((gpio_num_t)GPIO_STATUS_LED, 0);

    const esp_timer_create_args_t timer_args = {
        .callback = &led_timer_callback,
        .name = "status_led_timer"
    };
    esp_timer_create(&timer_args, &s_led_timer);

    const esp_timer_create_args_t action_timer_args = {
        .callback = &action_timer_callback,
        .name = "status_led_action_timer"
    };
    esp_timer_create(&action_timer_args, &s_action_timer);
#endif

    status_led_set_pattern(STATUS_LED_FAST_BLINK);
    ESP_LOGI(TAG, "Status LED initialized on GPIO %d", GPIO_STATUS_LED);
}

void status_led_set_pattern(status_led_pattern_t pattern)
{
    s_current_pattern = pattern;

#ifdef ESP_PLATFORM
    if (!s_led_timer) return;

    esp_timer_stop(s_led_timer);
    s_cycle_step = 0;
    s_action_feedback_active = false;

    switch (pattern) {
        case STATUS_LED_OFF:
            set_physical_led(false);
            break;
        case STATUS_LED_SOLID_ON:
            set_physical_led(true);
            break;
        case STATUS_LED_FAST_BLINK: // 150ms
            set_physical_led(true);
            esp_timer_start_periodic(s_led_timer, 150 * 1000);
            break;
        case STATUS_LED_SLOW_BLINK: // 500ms
            set_physical_led(true);
            esp_timer_start_periodic(s_led_timer, 500 * 1000);
            break;
        case STATUS_LED_MEDIUM_BLINK: // 200ms
            set_physical_led(true);
            esp_timer_start_periodic(s_led_timer, 200 * 1000);
            break;
        case STATUS_LED_HEARTBEAT: // 100ms base step (2.5s cycle)
            set_physical_led(true);
            esp_timer_start_periodic(s_led_timer, 100 * 1000);
            break;
        case STATUS_LED_DOUBLE_BLINK: // 100ms intervals (1.8s cycle)
            set_physical_led(true);
            esp_timer_start_periodic(s_led_timer, 100 * 1000);
            break;
        case STATUS_LED_RAPID_BURST: // 50ms
        case STATUS_LED_OTA_UPDATING:
            set_physical_led(true);
            esp_timer_start_periodic(s_led_timer, 50 * 1000);
            break;
    }
#endif
    ESP_LOGI(TAG, "Status LED pattern set: %d", pattern);
}

void status_led_trigger_action_feedback(void)
{
#ifdef ESP_PLATFORM
    if (!s_action_timer) return;

    s_action_feedback_active = true;
    // Invert current level for 80ms to provide instantaneous user touch feedback
    if (s_current_pattern == STATUS_LED_SOLID_ON) {
        set_physical_led(false); // Quick dark dip
    } else {
        set_physical_led(true);  // Quick bright flash
    }

    esp_timer_stop(s_action_timer);
    esp_timer_start_once(s_action_timer, 80 * 1000); // 80ms one-shot pulse
#endif
}

void status_led_set_lifecycle_state(app_lifecycle_state_t state)
{
    switch (state) {
        case APP_STATE_FACTORY_NEW:
        case APP_STATE_BLE_COMMISSIONING:
            status_led_set_pattern(STATUS_LED_FAST_BLINK);
            break;
        case APP_STATE_WIFI_CONNECTING:
            status_led_set_pattern(STATUS_LED_SLOW_BLINK);
            break;
        case APP_STATE_LOCAL_OPERATIONAL:
            status_led_set_pattern(STATUS_LED_HEARTBEAT);
            break;
        case APP_STATE_MQTT_CONNECTING:
            status_led_set_pattern(STATUS_LED_MEDIUM_BLINK);
            break;
        case APP_STATE_ACTIVE:
            status_led_set_pattern(STATUS_LED_SOLID_ON);
            break;
        case APP_STATE_ERROR_RECOVERY:
            status_led_set_pattern(STATUS_LED_DOUBLE_BLINK);
            break;
        case APP_STATE_OTA_UPDATING:
            status_led_set_pattern(STATUS_LED_OTA_UPDATING);
            break;
        default:
            status_led_set_pattern(STATUS_LED_FAST_BLINK);
            break;
    }
}

void status_led_lifecycle_listener(app_lifecycle_state_t old_state, app_lifecycle_state_t new_state)
{
    (void)old_state;
    status_led_set_lifecycle_state(new_state);
}
