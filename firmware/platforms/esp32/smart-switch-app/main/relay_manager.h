#ifndef EH_RELAY_MANAGER_H
#define EH_RELAY_MANAGER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define EH_RELAY_CHANNEL_COUNT 3

// GPIO assignments according to metadata.json
#define GPIO_RELAY_CH1 18
#define GPIO_RELAY_CH2 19
#define GPIO_RELAY_CH3 20

typedef void (*relay_state_change_cb_t)(uint8_t channel_index, bool new_power, const char* source);

/**
 * Initialize relay GPIOs as outputs in deterministic OFF state.
 */
void relay_manager_init(void);

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
