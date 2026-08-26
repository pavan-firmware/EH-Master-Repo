#ifndef EH_OTA_MANAGER_H
#define EH_OTA_MANAGER_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    EH_OTA_STATE_IDLE = 0,
    EH_OTA_STATE_DOWNLOADING,
    EH_OTA_STATE_VERIFYING,
    EH_OTA_STATE_INSTALLING,
    EH_OTA_STATE_REBOOTING,
    EH_OTA_STATE_ROLLED_BACK,
    EH_OTA_STATE_FAILED
} eh_ota_state_t;

typedef struct {
    char version[32];
    char min_version[32];
    char sha256[65];
    char download_url[256];
    size_t binary_size_bytes;
} eh_ota_manifest_t;

/**
 * Initialize OTA subsystem and check if running image is awaiting confirmation.
 */
void ota_manager_init(void);

/**
 * Get current OTA progress state.
 */
eh_ota_state_t ota_manager_get_state(void);

/**
 * Compare semver strings (returns >0 if v1 > v2, 0 if v1==v2, <0 if v1 < v2).
 */
int ota_semver_compare(const char* v1, const char* v2);

/**
 * Validate manifest against running version for anti-rollback.
 * Returns true if update is permitted.
 */
bool ota_validate_manifest(const eh_ota_manifest_t* manifest, const char* current_version);

/**
 * Confirm boot validity to prevent automatic bootloader rollback.
 * Call only after successful Wi-Fi + MQTT connection.
 */
void ota_manager_confirm_boot_valid(void);

/**
 * Start OTA update with given manifest.
 */
bool ota_manager_start_update(const eh_ota_manifest_t* manifest);

#ifdef __cplusplus
}
#endif

#endif /* EH_OTA_MANAGER_H */
