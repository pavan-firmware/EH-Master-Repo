#ifndef EH_SWITCH_MANAGER_H
#define EH_SWITCH_MANAGER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef ESP_PLATFORM
#include "sdkconfig.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define EH_SWITCH_CHANNEL_COUNT 3
#define EH_SWITCH_DEBOUNCE_MS 50

// Target-Specific Hardware Pin Mapping
#if defined(CONFIG_IDF_TARGET_ESP32)
// ESP32-D0WD Development Board Profile: GPIO 4, 5, 13 (Safe user inputs, avoids SPI flash pins)
#define GPIO_SWITCH_IN_CH1 4
#define GPIO_SWITCH_IN_CH2 5
#define GPIO_SWITCH_IN_CH3 13
#elif defined(CONFIG_IDF_TARGET_ESP32C6) || defined(CONFIG_IDF_TARGET_ESP32C3)
// ESP32-C6 / ESP32-C3 Production Profile: GPIO 4, 5, 6
#define GPIO_SWITCH_IN_CH1 4
#define GPIO_SWITCH_IN_CH2 5
#define GPIO_SWITCH_IN_CH3 6
#elif !defined(ESP_PLATFORM)
// Host simulation fallback
#define GPIO_SWITCH_IN_CH1 4
#define GPIO_SWITCH_IN_CH2 5
#define GPIO_SWITCH_IN_CH3 6
#else
#error "Unsupported EH Home MCU target in switch_manager.h"
#endif

typedef struct {
    uint8_t channel_index;
    uint32_t timestamp_ms;
} switch_event_t;

typedef void (*switch_toggle_cb_t)(uint8_t channel_index);
typedef void (*switch_long_press_cb_t)(uint8_t channel_index);

/**
 * Initialize switch GPIOs as inputs with pull-ups and interrupt on both edges.
 */
void switch_manager_init(void);

/**
 * Register callback called immediately upon debounced switch toggle.
 */
void switch_manager_register_cb(switch_toggle_cb_t cb);

/**
 * Register callback called when a switch channel is held continuously (> 5 seconds).
 */
void switch_manager_register_long_press_cb(switch_long_press_cb_t cb);

/**
 * Process debounce logic (callable in test or FreeRTOS task loop).
 * Returns true if a valid toggle was detected on channel_index after debounce.
 */
bool switch_manager_feed_event(uint8_t channel_index, uint32_t current_time_ms);

#ifdef __cplusplus
}
#endif

#endif /* EH_SWITCH_MANAGER_H */
