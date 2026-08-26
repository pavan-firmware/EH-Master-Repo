#ifndef EH_WIFI_MANAGER_H
#define EH_WIFI_MANAGER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*wifi_connected_cb_t)(const char* ip_address);
typedef void (*wifi_disconnected_cb_t)(void);

/**
 * Initialize Wi-Fi station stack and event handlers.
 */
void wifi_manager_init(void);

/**
 * Configure Wi-Fi credentials (e.g. from EH-PROV/1 payload).
 * Passwords MUST NOT be logged.
 */
bool wifi_manager_set_credentials(const char* ssid, const char* password);

/**
 * Connect to configured AP.
 */
void wifi_manager_connect(void);

/**
 * Disconnect from AP.
 */
void wifi_manager_disconnect(void);

/**
 * Check if Wi-Fi is currently connected with valid IP.
 */
bool wifi_manager_is_connected(void);

/**
 * Register connection and disconnection callbacks.
 */
void wifi_manager_register_callbacks(wifi_connected_cb_t on_connected, wifi_disconnected_cb_t on_disconnected);

#ifdef __cplusplus
}
#endif

#endif /* EH_WIFI_MANAGER_H */
