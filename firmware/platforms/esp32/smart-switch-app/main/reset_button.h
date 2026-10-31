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

#include "board_pinout.h"

// Hardware Pin Mapping sourced from canonical board_pinout.h
#define GPIO_RESET_BUTTON EH_PIN_BUTTON_RESET

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
 * Manually trigger software-initiated factory reset (e.g. from App 'Forget Device' local command).
 */
void reset_button_trigger_factory_reset(void);

/**
 * Testable state machine step for simulated/host evaluation.
 * Returns true if factory reset was triggered.
 */
bool reset_button_feed_state(bool is_pressed, uint32_t delta_ms);

#ifdef __cplusplus
}
#endif

#endif /* EH_RESET_BUTTON_H */
