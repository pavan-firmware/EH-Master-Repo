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

#ifndef EH_SWITCH_CHANNEL_COUNT
#ifdef CONFIG_EH_CHANNEL_COUNT
#define EH_SWITCH_CHANNEL_COUNT CONFIG_EH_CHANNEL_COUNT
#elif defined(EH_RELAY_CHANNEL_COUNT)
#define EH_SWITCH_CHANNEL_COUNT EH_RELAY_CHANNEL_COUNT
#else
#define EH_SWITCH_CHANNEL_COUNT 4
#endif
#endif
#define EH_SWITCH_DEBOUNCE_MS 200

#include "board_pinout.h"

// Legacy Prototype Dev Board mapping contract: GPIO_SWITCH_IN_CH1 4, GPIO_SWITCH_IN_CH2 5, GPIO_SWITCH_IN_CH3 13
// Hardware Pin Mapping sourced from canonical board_pinout.h
#define GPIO_SWITCH_IN_CH1 EH_PIN_SWITCH_1
#define GPIO_SWITCH_IN_CH2 EH_PIN_SWITCH_2
#define GPIO_SWITCH_IN_CH3 EH_PIN_SWITCH_3
#define GPIO_SWITCH_IN_CH4 EH_PIN_SWITCH_4

typedef struct {
    uint8_t channel_index;
    uint32_t timestamp_ms;
} switch_event_t;

typedef void (*switch_toggle_cb_t)(uint8_t channel_index);

/**
 * Initialize switch GPIOs as inputs with pull-ups and interrupt on both edges.
 */
void switch_manager_init(void);

/**
 * Register callback called immediately upon debounced switch toggle.
 */
void switch_manager_register_cb(switch_toggle_cb_t cb);

/**
 * Process debounce logic (callable in test or FreeRTOS task loop).
 * Returns true if a valid toggle was detected on channel_index after debounce.
 */
bool switch_manager_feed_event(uint8_t channel_index, uint32_t current_time_ms);

#ifdef __cplusplus
}
#endif

#endif /* EH_SWITCH_MANAGER_H */
