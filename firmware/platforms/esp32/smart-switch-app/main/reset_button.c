#include "reset_button.h"
#include "wifi_manager.h"
#include "factory_identity_v2.h"
#include "status_led.h"

#include "relay_manager.h"

#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_system.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#define TAG "RESET_BUTTON"
#else
#define TAG "RESET_BUTTON"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static factory_reset_trigger_cb_t s_reset_cb = NULL;
static uint32_t s_press_duration_ms = 0;
static bool s_reset_triggered = false;

bool reset_button_feed_state(bool is_pressed, uint32_t delta_ms)
{
    if (is_pressed) {
        s_press_duration_ms += delta_ms;
        if (s_press_duration_ms >= FACTORY_RESET_HOLD_MS && !s_reset_triggered) {
            s_reset_triggered = true;
            ESP_LOGW(TAG, "Factory reset button held for %u ms (>= %u ms). Triggering factory reset!",
                     (unsigned int)s_press_duration_ms, (unsigned int)FACTORY_RESET_HOLD_MS);
            if (s_reset_cb) {
                s_reset_cb();
            }
            return true;
        }
    } else {
        if (s_press_duration_ms > 0 && s_press_duration_ms < FACTORY_RESET_HOLD_MS) {
            ESP_LOGI(TAG, "Reset button released after %u ms (< %u ms required). Reset ignored.",
                     (unsigned int)s_press_duration_ms, (unsigned int)FACTORY_RESET_HOLD_MS);
        }
        s_press_duration_ms = 0;
        s_reset_triggered = false;
    }
    return false;
}

#ifdef ESP_PLATFORM
static void execute_factory_reset_and_reboot(void)
{
    ESP_LOGW(TAG, "==================================================");
    ESP_LOGW(TAG, "[FACTORY RESET] CLEARING NVS USER CREDENTIALS & REBOOTING");
    ESP_LOGW(TAG, "==================================================");

    // 1. Indicate rapid burst on status LED
    status_led_set_pattern(STATUS_LED_RAPID_BURST);

    // 2. Erase stored Wi-Fi credentials
    wifi_manager_clear_credentials();

    // 3. Reset commissioning secret consumed flag (re-arms BLE onboarding secret)
    factory_identity_v2_factory_reset();

    // 4. Clear persisted relay states back to fresh default (all OFF)
    relay_manager_clear_persisted_states();

    // 4. Custom callback if registered
    if (s_reset_cb) {
        s_reset_cb();
    }

    // 5. Allow flash operations to commit and logs to flush
    vTaskDelay(pdMS_TO_TICKS(500));

    // 6. Reboot to BLE commissioning
    esp_restart();
}

static void reset_button_task(void* arg)
{
    (void)arg;
    const uint32_t poll_period_ms = 50;

    while (1) {
        // Active LOW button: 0 = pressed, 1 = released
        int level = gpio_get_level((gpio_num_t)GPIO_RESET_BUTTON);
        bool is_pressed = (level == 0);

        if (reset_button_feed_state(is_pressed, poll_period_ms)) {
            execute_factory_reset_and_reboot();
            break;
        }

        vTaskDelay(pdMS_TO_TICKS(poll_period_ms));
    }
    vTaskDelete(NULL);
}
#endif

void reset_button_init(void)
{
#ifdef ESP_PLATFORM
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << GPIO_RESET_BUTTON),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);

    xTaskCreate(reset_button_task, "reset_btn_task", 3072, NULL, 5, NULL);
#endif
    ESP_LOGI(TAG, "Factory reset button monitor initialized on GPIO %d (Hold duration: %d ms)",
             GPIO_RESET_BUTTON, FACTORY_RESET_HOLD_MS);
}

void reset_button_register_callback(factory_reset_trigger_cb_t cb)
{
    s_reset_cb = cb;
}
