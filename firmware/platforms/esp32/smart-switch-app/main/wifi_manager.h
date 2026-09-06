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
 * Initialize Wi-Fi station stack and load persisted credentials from NVS if present.
 * NOTE: wifi_manager_init() does NOT initiate connection automatically;
 * the application state machine explicitly controls when to call wifi_manager_connect().
 */
void wifi_manager_init(void);

/**
 * Check if valid non-empty Wi-Fi credentials exist in storage.
 */
bool wifi_manager_has_credentials(void);

/**
 * Configure and persist Wi-Fi credentials (e.g. from EH-PROV/1 payload).
 * Credentials are saved to NVS. Passwords MUST NOT be logged.
 */
bool wifi_manager_set_credentials(const char* ssid, const char* password);

/**
 * Retrieve currently configured / stored SSID and password (safe buffer copy).
 */
bool wifi_manager_get_credentials(char* out_ssid, size_t ssid_len, char* out_password, size_t pass_len);

/**
 * Clear stored Wi-Fi credentials from NVS (for factory reset / re-commissioning).
 */
bool wifi_manager_clear_credentials(void);

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
