#ifndef EH_APP_LIFECYCLE_H
#define EH_APP_LIFECYCLE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    APP_STATE_FACTORY_NEW = 0,
    APP_STATE_BLE_COMMISSIONING,
    APP_STATE_WIFI_CONNECTING,
    APP_STATE_MQTT_CONNECTING,
    APP_STATE_ACTIVE,
    APP_STATE_ERROR_RECOVERY
} app_lifecycle_state_t;

typedef void (*app_lifecycle_listener_t)(app_lifecycle_state_t old_state, app_lifecycle_state_t new_state);

void app_lifecycle_init(void);
app_lifecycle_state_t app_lifecycle_get_state(void);
bool app_lifecycle_set_state(app_lifecycle_state_t new_state);
const char* app_lifecycle_get_state_name(app_lifecycle_state_t state);
void app_lifecycle_register_listener(app_lifecycle_listener_t listener);

/**
 * Commissioning secret access rule:
 * Secret is available ONLY when state is FACTORY_NEW or BLE_COMMISSIONING and not yet consumed.
 * Once marked active/commissioned, the secret is locked and cannot be retrieved.
 */
bool app_lifecycle_is_secret_accessible(void);
void app_lifecycle_mark_commissioned(void);

/**
 * Execute canonical safe selective factory reset:
 * Clears runtime keys (Wi-Fi, lifecycle, session), preserves factory identity,
 * handles development comm_cons semantics, verifies integrity, and reboots.
 */
bool app_lifecycle_factory_reset(void);

#ifdef __cplusplus
}
#endif

#endif /* EH_APP_LIFECYCLE_H */
