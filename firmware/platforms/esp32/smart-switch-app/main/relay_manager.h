#ifndef EH_RELAY_MANAGER_H
#define EH_RELAY_MANAGER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef ESP_PLATFORM
#include "sdkconfig.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef EH_RELAY_CHANNEL_COUNT
#ifdef CONFIG_EH_CHANNEL_COUNT
#define EH_RELAY_CHANNEL_COUNT CONFIG_EH_CHANNEL_COUNT
#else
#define EH_RELAY_CHANNEL_COUNT 4
#endif
#endif

#include "board_pinout.h"

// Relay Module Trigger Logic:
// 0 for Active-LOW optocoupler relay modules (Standard multi-channel relay modules: LOW = ON, HIGH = OFF)
// Configurable trigger logic (Active-HIGH reference: #define EH_RELAY_ACTIVE_LEVEL 1)
#ifndef EH_RELAY_ACTIVE_LEVEL
#define EH_RELAY_ACTIVE_LEVEL 0
#endif
#define EH_RELAY_POWER_TO_LEVEL(pwr) ((pwr) ? EH_RELAY_ACTIVE_LEVEL : (!EH_RELAY_ACTIVE_LEVEL))

// Legacy Prototype Dev Board mapping contract: GPIO_RELAY_CH1 18, GPIO_RELAY_CH2 19, GPIO_RELAY_CH3 21
// Hardware Pin Mapping sourced from canonical board_pinout.h
#define GPIO_RELAY_CH1 EH_PIN_RELAY_1
#define GPIO_RELAY_CH2 EH_PIN_RELAY_2
#define GPIO_RELAY_CH3 EH_PIN_RELAY_3
#define GPIO_RELAY_CH4 EH_PIN_RELAY_4

typedef void (*relay_state_change_cb_t)(uint8_t channel_index, bool new_power, const char* source);

/**
 * Initialize relay GPIOs as outputs and restore last persisted NVS states (or default to OFF).
 */
void relay_manager_init(void);

/**
 * Clear persisted relay states from NVS (for factory reset).
 */
void relay_manager_clear_persisted_states(void);

/**
 * Set power for a specific channel (1-indexed: 1..3).
 * Returns true if channel is valid and state applied.
 */
bool relay_manager_set_power(uint8_t channel_index, bool power, const char* source);

/**
 * Toggle power for a specific channel.
 */
bool relay_manager_toggle_power(uint8_t channel_index, const char* source);

/**
 * Get current power state for a channel (1..3).
 */
bool relay_manager_get_power(uint8_t channel_index);

/**
 * Register callback to receive notification on state changes.
 */
void relay_manager_register_change_cb(relay_state_change_cb_t cb);

#ifdef __cplusplus
}
#endif

#endif /* EH_RELAY_MANAGER_H */
