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

#ifdef __cplusplus
}
#endif

#endif /* EH_LOCAL_SERVER_H */
