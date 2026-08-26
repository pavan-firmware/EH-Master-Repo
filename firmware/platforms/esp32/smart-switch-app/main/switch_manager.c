#include "switch_manager.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "esp_timer.h"
#define TAG "SWITCH_MGR"
#else
#define TAG "SWITCH_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static const int s_switch_gpios[EH_SWITCH_CHANNEL_COUNT] = {
    GPIO_SWITCH_IN_CH1,
    GPIO_SWITCH_IN_CH2,
    GPIO_SWITCH_IN_CH3
};

static uint32_t s_last_trigger_ms[EH_SWITCH_CHANNEL_COUNT] = { 0, 0, 0 };
static switch_toggle_cb_t s_toggle_cb = NULL;

#ifdef ESP_PLATFORM
static QueueHandle_t s_switch_evt_queue = NULL;

static void IRAM_ATTR gpio_isr_handler(void* arg)
{
    uint32_t gpio_num = (uint32_t) arg;
    uint8_t ch = 0;
    if (gpio_num == GPIO_SWITCH_IN_CH1) ch = 1;
    else if (gpio_num == GPIO_SWITCH_IN_CH2) ch = 2;
    else if (gpio_num == GPIO_SWITCH_IN_CH3) ch = 3;

    if (ch > 0 && s_switch_evt_queue != NULL) {
        switch_event_t evt = {
            .channel_index = ch,
            .timestamp_ms = (uint32_t)(esp_timer_get_time() / 1000)
        };
        BaseType_t high_task_wakeup = pdFALSE;
        xQueueSendFromISR(s_switch_evt_queue, &evt, &high_task_wakeup);
        if (high_task_wakeup) {
            portYIELD_FROM_ISR();
        }
    }
}

static void switch_task(void* arg)
{
    switch_event_t evt;
    while (1) {
        if (xQueueReceive(s_switch_evt_queue, &evt, portMAX_DELAY)) {
            if (switch_manager_feed_event(evt.channel_index, evt.timestamp_ms)) {
                if (s_toggle_cb) {
                    s_toggle_cb(evt.channel_index);
                }
            }
        }
    }
}
#endif

void switch_manager_init(void)
{
    memset(s_last_trigger_ms, 0, sizeof(s_last_trigger_ms));

#ifdef ESP_PLATFORM
    s_switch_evt_queue = xQueueCreate(16, sizeof(switch_event_t));

    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << GPIO_SWITCH_IN_CH1) | (1ULL << GPIO_SWITCH_IN_CH2) | (1ULL << GPIO_SWITCH_IN_CH3),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_ANYEDGE
    };
    gpio_config(&io_conf);

    gpio_install_isr_service(0);
    for (int i = 0; i < EH_SWITCH_CHANNEL_COUNT; i++) {
        gpio_isr_handler_add((gpio_num_t)s_switch_gpios[i], gpio_isr_handler, (void*)s_switch_gpios[i]);
    }

    xTaskCreate(switch_task, "switch_task", 2048, NULL, 10, NULL);
#endif

    ESP_LOGI(TAG, "Switches initialized (CH1: GPIO%d, CH2: GPIO%d, CH3: GPIO%d) with %dms debounce",
             GPIO_SWITCH_IN_CH1, GPIO_SWITCH_IN_CH2, GPIO_SWITCH_IN_CH3, EH_SWITCH_DEBOUNCE_MS);
}

bool switch_manager_feed_event(uint8_t channel_index, uint32_t current_time_ms)
{
    if (channel_index < 1 || channel_index > EH_SWITCH_CHANNEL_COUNT) {
        return false;
    }

    uint8_t idx = channel_index - 1;
    uint32_t last = s_last_trigger_ms[idx];

    if (current_time_ms - last >= EH_SWITCH_DEBOUNCE_MS || last == 0) {
        s_last_trigger_ms[idx] = current_time_ms;
        ESP_LOGI(TAG, "Physical switch toggle confirmed on CH%d at %u ms", channel_index, (unsigned int)current_time_ms);
        return true;
    }

    // Debounce filtered out
    return false;
}

void switch_manager_register_cb(switch_toggle_cb_t cb)
{
    s_toggle_cb = cb;
}
