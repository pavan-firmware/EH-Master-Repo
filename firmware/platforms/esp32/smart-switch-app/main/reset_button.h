#ifndef EH_RESET_BUTTON_H
#define EH_RESET_BUTTON_H

#include <stdbool.h>
#include <stdint.h>

#ifdef ESP_PLATFORM
#include "sdkconfig.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Target-Specific Factory Reset Button Pin Mapping
#if defined(CONFIG_IDF_TARGET_ESP32)
// ESP32-D0WD Development Board Profile: GPIO 0 (BOOT button, active LOW)
#define GPIO_RESET_BUTTON 0
#elif defined(CONFIG_IDF_TARGET_ESP32C6) || defined(CONFIG_IDF_TARGET_ESP32C3)
// ESP32-C6 / ESP32-C3 Production Profile: GPIO 9 (BOOT button, active LOW)
#define GPIO_RESET_BUTTON 9
#elif !defined(ESP_PLATFORM)
// Host simulation fallback
#define GPIO_RESET_BUTTON 0
#else
#error "Unsupported EH Home MCU target in reset_button.h"
#endif

#define FACTORY_RESET_HOLD_MS 10000 // 10 seconds hold required

typedef void (*factory_reset_trigger_cb_t)(void);

/**
 * Initialize factory reset button GPIO with internal pull-up and start background monitor task.
 */
void reset_button_init(void);

/**
 * Register optional custom callback executed immediately before reboot during factory reset.
 */
void reset_button_register_callback(factory_reset_trigger_cb_t cb);

/**
 * Testable state machine step for simulated/host evaluation.
 * Returns true if factory reset was triggered.
 */
bool reset_button_feed_state(bool is_pressed, uint32_t delta_ms);

#ifdef __cplusplus
}
#endif

#endif /* EH_RESET_BUTTON_H */
