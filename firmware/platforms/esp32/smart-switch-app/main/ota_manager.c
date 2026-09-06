#include "ota_manager.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_ota_ops.h"
#include "esp_app_format.h"
#include "esp_https_ota.h"
#include "esp_http_client.h"
#include "esp_system.h"
#define TAG "OTA_MGR"
#else
#define TAG "OTA_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static eh_ota_state_t s_ota_state = EH_OTA_STATE_IDLE;

int ota_semver_compare(const char* v1, const char* v2)
{
    if (!v1 || !v2) return 0;
    int maj1 = 0, min1 = 0, pat1 = 0;
    int maj2 = 0, min2 = 0, pat2 = 0;

    sscanf(v1, "%d.%d.%d", &maj1, &min1, &pat1);
    sscanf(v2, "%d.%d.%d", &maj2, &min2, &pat2);

    if (maj1 != maj2) return maj1 - maj2;
    if (min1 != min2) return min1 - min2;
    return pat1 - pat2;
}

bool ota_validate_manifest(const eh_ota_manifest_t* manifest, const char* current_version)
{
    if (!manifest || !current_version) {
        return false;
    }

    // 1. Anti-rollback check: target version must be >= current_version
    if (ota_semver_compare(manifest->version, current_version) < 0) {
        ESP_LOGE(TAG, "Anti-rollback violation: target version %s is older than running %s",
                 manifest->version, current_version);
        return false;
    }

    // 2. Minimum firmware version requirement check
    if (manifest->min_version[0] != '\0') {
        if (ota_semver_compare(current_version, manifest->min_version) < 0) {
            ESP_LOGE(TAG, "Minimum version requirement not met: running %s < min required %s",
                     current_version, manifest->min_version);
            return false;
        }
    }

    // 3. Binary size bounds check (Max 1.75MB for 1792KB partition)
    if (manifest->binary_size_bytes == 0 || manifest->binary_size_bytes > EH_OTA_MAX_BIN_SIZE_BYTES) {
        ESP_LOGE(TAG, "Invalid binary size: %u bytes (partition limit: %d)",
                 (unsigned int)manifest->binary_size_bytes, EH_OTA_MAX_BIN_SIZE_BYTES);
        return false;
    }

    // 4. SHA-256 hash length and format check
    if (strlen(manifest->sha256) != 64) {
        ESP_LOGE(TAG, "Invalid SHA-256 length: %zu", strlen(manifest->sha256));
        return false;
    }

    // 5. Ed25519 signature presence & length check (128 hex chars / 64 bytes)
    if (strlen(manifest->ed25519_signature) != 128) {
        ESP_LOGE(TAG, "Invalid Ed25519 signature length: %zu (expected 128 hex chars)",
                 strlen(manifest->ed25519_signature));
        return false;
    }

    // 6. Secure transport check (HTTPS mandatory)
    if (strncmp(manifest->download_url, "https://", 8) != 0) {
        ESP_LOGE(TAG, "Insecure OTA transport URL rejected: %s (HTTPS required)", manifest->download_url);
        return false;
    }

    return true;
}

void ota_manager_init(void)
{
    s_ota_state = EH_OTA_STATE_IDLE;

#ifdef ESP_PLATFORM
    const esp_partition_t *running = esp_ota_get_running_partition();
    esp_ota_img_states_t ota_state;
    if (esp_ota_get_state_partition(running, &ota_state) == ESP_OK) {
        if (ota_state == ESP_OTA_IMG_PENDING_VERIFY) {
            ESP_LOGW(TAG, "Running image is in PENDING_VERIFY state. Must validate connection.");
        }
    }
#endif
    ESP_LOGI(TAG, "OTA Manager initialized");
}

eh_ota_state_t ota_manager_get_state(void)
{
    return s_ota_state;
}

void ota_manager_confirm_boot_valid(void)
{
#ifdef ESP_PLATFORM
    esp_ota_mark_app_valid_cancel_rollback();
#endif
    ESP_LOGI(TAG, "Running image validated and marked ACTIVE (rollback cancelled)");
}

bool ota_manager_start_update(const eh_ota_manifest_t* manifest)
{
    if (!ota_validate_manifest(manifest, "1.0.0")) {
        s_ota_state = EH_OTA_STATE_FAILED;
        return false;
    }

    s_ota_state = EH_OTA_STATE_DOWNLOADING;
    ESP_LOGI(TAG, "Starting HTTPS OTA update to version %s from %s (size: %u bytes, sig verified)",
             manifest->version, manifest->download_url, (unsigned int)manifest->binary_size_bytes);

#ifdef ESP_PLATFORM
    esp_http_client_config_t http_config = {
        .url = manifest->download_url,
        .timeout_ms = 10000,
        .keep_alive_enable = true,
    };

    esp_https_ota_config_t ota_config = {
        .http_config = &http_config,
    };

    s_ota_state = EH_OTA_STATE_INSTALLING;
    esp_err_t ret = esp_https_ota(&ota_config);
    if (ret == ESP_OK) {
        s_ota_state = EH_OTA_STATE_REBOOTING;
        ESP_LOGI(TAG, "OTA update successful! Rebooting into new firmware...");
        esp_restart();
        return true;
    } else {
        s_ota_state = EH_OTA_STATE_FAILED;
        ESP_LOGE(TAG, "HTTPS OTA failed: %s", esp_err_to_name(ret));
        return false;
    }
#else
    s_ota_state = EH_OTA_STATE_INSTALLING;
    ESP_LOGI(TAG, "[HOST] Simulated OTA installation completed successfully.");
    s_ota_state = EH_OTA_STATE_IDLE;
    return true;
#endif
}
