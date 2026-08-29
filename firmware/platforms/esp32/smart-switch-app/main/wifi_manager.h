#ifndef EH_WIFI_MANAGER_H
#define EH_WIFI_MANAGER_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

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
 * Save Wi-Fi credentials to persistent NVS storage.
 */
bool wifi_manager_save_credentials(const char* ssid, const char* password);

/**
 * Load stored Wi-Fi credentials from persistent NVS storage.
 */
bool wifi_manager_load_credentials(char* out_ssid, size_t max_ssid_len, char* out_pass, size_t max_pass_len);

/**
 * Check if valid Wi-Fi credentials exist in NVS storage.
 */
bool wifi_manager_has_credentials(void);

/**
 * Clear stored Wi-Fi credentials from NVS storage (e.g. factory reset).
 */
void wifi_manager_clear_credentials(void);

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
