#ifndef EH_TIME_SYNC_MANAGER_H
#define EH_TIME_SYNC_MANAGER_H

#include <stdbool.h>
#include <stdint.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DEFAULT_NTP_SERVER_1 "pool.ntp.org"
#define DEFAULT_NTP_SERVER_2 "time.google.com"
#define DEFAULT_TIMEZONE "IST-5:30"
#define MIN_VALID_EPOCH 1735689600ULL // 2025-01-01 00:00:00 UTC

/**
 * Initialize the Resilient Time Synchronization Manager.
 * Configures default timezone (IST), starts non-blocking SNTP state machine,
 * and tracks sync state. Zero flash writes for clock ticks.
 */
void time_sync_manager_init(void);

/**
 * Start SNTP background synchronization client (call after network/WiFi is ready).
 */
void time_sync_manager_start_sntp(void);

/**
 * Check if the internal RTC has been successfully synchronized
 * (via NTP or passive local phone app epoch injection).
 * @return true if valid epoch >= 2025-01-01 is loaded.
 */
bool time_sync_manager_is_synced(void);

/**
 * Get current system epoch timestamp in seconds.
 */
time_t time_sync_manager_get_epoch(void);

/**
 * Non-blocking tick called periodically (e.g. from FreeRTOS task or 1s timer)
 * to manage retry state machine (10-15s when unsynced, 24h when synced).
 */
void time_sync_manager_tick(void);

/**
 * Passive / Local Epoch Injection:
 * Updates internal RTC via settimeofday() without writing to flash.
 * Sets is_time_synced to true if epoch is valid (>= 2025).
 * 
 * @param unix_sec Unix epoch timestamp in seconds.
 * @param source Diagnostic source tag (e.g. "LOCAL_APP_HTTP", "UDP_DISCOVERY", "CLOUD_SYNC").
 * @return true if timestamp was accepted and RTC updated.
 */
bool time_sync_manager_inject_epoch(uint64_t unix_sec, const char* source);

/**
 * Set dynamic timezone string (e.g. "IST-5:30" or custom POSIX TZ string).
 */
void time_sync_manager_set_timezone(const char* tz_str);

/**
 * Force manual NTP re-synchronization request.
 */
void time_sync_manager_request_ntp_sync(void);

#ifdef __cplusplus
}
#endif

#endif /* EH_TIME_SYNC_MANAGER_H */
