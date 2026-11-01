#ifndef EH_STATUS_LED_H
#define EH_STATUS_LED_H

#include <stdbool.h>
#include <stdint.h>

#ifdef ESP_PLATFORM
#include "sdkconfig.h"
#endif

#include "app_lifecycle.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "board_pinout.h"

// Hardware Pin Mapping sourced from canonical board_pinout.h
#define GPIO_STATUS_LED EH_PIN_STATUS_LED
#define GPIO_STATUS_LED_ACTIVE_LEVEL 1

typedef enum {
    STATUS_LED_OFF = 0,
    STATUS_LED_FAST_BLINK,   // BLE Commissioning / Pairing (150ms ON / 150ms OFF)
    STATUS_LED_SLOW_BLINK,   // Wi-Fi Connecting (500ms ON / 500ms OFF)
    STATUS_LED_HEARTBEAT,    // Local LAN Mode (100ms short flash every 2.5s)
    STATUS_LED_MEDIUM_BLINK, // MQTT Connecting (200ms ON / 200ms OFF)
    STATUS_LED_SOLID_ON,     // Active / Cloud Connected (Solid ON)
    STATUS_LED_DOUBLE_BLINK, // Error / Network Lost (Double pulse with 1.5s pause)
    STATUS_LED_RAPID_BURST,  // Factory Reset (50ms rapid burst)
    STATUS_LED_OTA_UPDATING  // OTA Firmware Updating (50ms strobe)
} status_led_pattern_t;

/**
 * Initialize Status LED GPIO and background timer.
 */
void status_led_init(void);

/**
 * Set explicit LED pattern.
 */
void status_led_set_pattern(status_led_pattern_t pattern);

/**
 * Sync LED pattern to application lifecycle state.
 */
void status_led_set_lifecycle_state(app_lifecycle_state_t state);

/**
 * Trigger an instantaneous one-shot flash feedback for physical switch or app toggle.
 */
void status_led_trigger_action_feedback(void);

/**
 * Callback function to register directly with app_lifecycle_register_listener.
 */
void status_led_lifecycle_listener(app_lifecycle_state_t old_state, app_lifecycle_state_t new_state);

#ifdef __cplusplus
}
#endif

#endif /* EH_STATUS_LED_H */
