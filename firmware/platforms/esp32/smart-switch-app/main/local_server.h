#ifndef EH_LOCAL_SERVER_H
#define EH_LOCAL_SERVER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Start the local HTTP REST server on port 80.
 * Allows direct LAN control from mobile app when cloud/backend is offline.
 */
bool local_server_start(void);

/**
 * Stop the local HTTP REST server.
 */
void local_server_stop(void);

/**
 * Check if the local HTTP server is actively running.
 */
bool local_server_is_running(void);

/**
 * Broadcast real-time relay state changes over UDP port 4210 to local LAN clients.
 */
void local_server_broadcast_state(const bool* powers, uint8_t count);

/**
 * Broadcast boot announcement over UDP port 4210 to notify all LAN clients immediately on Wi-Fi connection.
 */
void local_server_broadcast_boot_announce(const bool* powers, uint8_t count);

/**
 * Start asynchronous 3-burst boot announcement (spaced 1.5s apart) on port 4210.
 */
void local_server_start_boot_announce_burst(const bool* powers, uint8_t count);

/**
 * Send Fast-Path Direct P2P UDP command to a peer device IP on port 4210 (<2ms dispatch).
 */
bool local_server_send_p2p_actuate(const char* target_ip, uint8_t target_channel, bool power, bool is_toggle);

/**
 * Send Fast-Path Direct P2P UDP command with optional targetDeviceId verification.
 */
bool local_server_send_p2p_actuate_target(const char* target_ip, const char* target_device_id, uint8_t target_channel, bool power, bool is_toggle);

#ifdef __cplusplus
}
#endif

#endif /* EH_LOCAL_SERVER_H */
