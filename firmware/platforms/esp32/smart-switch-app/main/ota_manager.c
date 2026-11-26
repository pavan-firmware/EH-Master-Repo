#include "ota_manager.h"
#include "status_led.h"
#include "app_lifecycle.h"
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
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mbedtls/sha256.h"
#define TAG "OTA_MGR"
#else
#define TAG "OTA_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

#ifndef EH_FIRMWARE_VERSION
#define EH_FIRMWARE_VERSION "1.1.0"
#endif

static volatile eh_ota_state_t s_ota_state = EH_OTA_STATE_IDLE;
static volatile int s_ota_progress_pct = 0;
static char s_ota_last_error[128] = {0};
static eh_ota_manifest_t s_pending_manifest;
static volatile bool s_ota_task_running = false;

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

    // 3. Binary size bounds check (if provided, must fit within 1792KB partition)
    if (manifest->binary_size_bytes > EH_OTA_MAX_BIN_SIZE_BYTES) {
        ESP_LOGE(TAG, "Invalid binary size: %u bytes (partition limit: %d)",
                 (unsigned int)manifest->binary_size_bytes, EH_OTA_MAX_BIN_SIZE_BYTES);
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Binary exceeds partition limit");
        return false;
    }

    // 4. SHA-256 hash format check (optional in local LAN, validated if provided)
    if (manifest->sha256[0] != '\0' && strlen(manifest->sha256) != 64) {
        ESP_LOGE(TAG, "Invalid SHA-256 length: %zu", strlen(manifest->sha256));
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Invalid SHA-256 format");
        return false;
    }

    // 5. Ed25519 signature format check (validated if provided)
    if (manifest->ed25519_signature[0] != '\0' && strlen(manifest->ed25519_signature) != 128) {
        ESP_LOGE(TAG, "Invalid Ed25519 signature length: %zu (expected 128 hex chars)",
                 strlen(manifest->ed25519_signature));
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Invalid Ed25519 signature");
        return false;
    }

    // 6. Transport check (HTTPS mandatory in production; local subnet HTTP permitted for LAN/Hub OTA)
    bool is_https = (strncmp(manifest->download_url, "https://", 8) == 0);
    bool is_local_http = (strncmp(manifest->download_url, "http://192.168.", 15) == 0) ||
                         (strncmp(manifest->download_url, "http://10.", 10) == 0) ||
                         (strncmp(manifest->download_url, "http://172.", 11) == 0) ||
                         (strncmp(manifest->download_url, "http://127.0.0.1", 16) == 0) ||
                         (strncmp(manifest->download_url, "http://localhost", 16) == 0);

    if (!is_https && !is_local_http) {
        ESP_LOGE(TAG, "Insecure OTA transport URL rejected: %s (HTTPS or local subnet required)", manifest->download_url);
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Invalid or non-local OTA URL");
        return false;
    }

    return true;
}

void ota_manager_init(void)
{
    s_ota_state = EH_OTA_STATE_IDLE;
    s_ota_progress_pct = 0;
    s_ota_last_error[0] = '\0';

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

int ota_manager_get_progress(void)
{
    return s_ota_progress_pct;
}

const char* ota_manager_get_last_error(void)
{
    return s_ota_last_error;
}

void ota_manager_confirm_boot_valid(void)
{
#ifdef ESP_PLATFORM
    esp_ota_mark_app_valid_cancel_rollback();
#endif
    ESP_LOGI(TAG, "Running image validated and marked ACTIVE (rollback cancelled)");
}

#ifdef ESP_PLATFORM
static bool run_http_streaming_ota(const eh_ota_manifest_t* manifest)
{
    const esp_partition_t *update_partition = esp_ota_get_next_update_partition(NULL);
    if (!update_partition) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "No target OTA partition available");
        ESP_LOGE(TAG, "%s", s_ota_last_error);
        return false;
    }

    esp_http_client_config_t config = {
        .url = manifest->download_url,
        .timeout_ms = 15000,
        .keep_alive_enable = true,
        .buffer_size = 4096,
    };
    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (!client) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Failed to init HTTP client");
        return false;
    }

    esp_err_t err = esp_http_client_open(client, 0);
    if (err != ESP_OK) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "HTTP open failed: %s", esp_err_to_name(err));
        ESP_LOGE(TAG, "%s", s_ota_last_error);
        esp_http_client_cleanup(client);
        return false;
    }

    int64_t content_length = esp_http_client_fetch_headers(client);
    int status_code = esp_http_client_get_status_code(client);
    if (status_code != 200) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "HTTP status %d downloading firmware", status_code);
        ESP_LOGE(TAG, "%s", s_ota_last_error);
        esp_http_client_close(client);
        esp_http_client_cleanup(client);
        return false;
    }

    esp_ota_handle_t update_handle = 0;
    err = esp_ota_begin(update_partition, OTA_WITH_SEQUENTIAL_WRITES, &update_handle);
    if (err != ESP_OK) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "esp_ota_begin failed: %s", esp_err_to_name(err));
        ESP_LOGE(TAG, "%s", s_ota_last_error);
        esp_http_client_close(client);
        esp_http_client_cleanup(client);
        return false;
    }

    s_ota_state = EH_OTA_STATE_INSTALLING;
    uint8_t *buf = (uint8_t *)malloc(4096);
    if (!buf) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Out of memory allocating OTA buffer");
        esp_ota_abort(update_handle);
        esp_http_client_close(client);
        esp_http_client_cleanup(client);
        return false;
    }

    mbedtls_sha256_context sha_ctx;
    bool check_sha = (strlen(manifest->sha256) == 64);
    if (check_sha) {
        mbedtls_sha256_init(&sha_ctx);
        mbedtls_sha256_starts(&sha_ctx, 0);
    }

    size_t total_written = 0;
    size_t expected_total = (content_length > 0) ? (size_t)content_length : manifest->binary_size_bytes;
    bool ok = true;

    while (1) {
        int data_read = esp_http_client_read(client, (char *)buf, 4096);
        if (data_read < 0) {
            snprintf(s_ota_last_error, sizeof(s_ota_last_error), "HTTP read error during download");
            ok = false;
            break;
        } else if (data_read == 0) {
            if (esp_http_client_is_complete_data_received(client)) {
                break;
            }
            snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Incomplete firmware stream");
            ok = false;
            break;
        }

        if (check_sha) {
            mbedtls_sha256_update(&sha_ctx, buf, data_read);
        }
        err = esp_ota_write(update_handle, buf, data_read);
        if (err != ESP_OK) {
            snprintf(s_ota_last_error, sizeof(s_ota_last_error), "esp_ota_write failed: %s", esp_err_to_name(err));
            ok = false;
            break;
        }
        total_written += (size_t)data_read;
        if (expected_total > 0) {
            int pct = (int)((total_written * 95ULL) / expected_total);
            if (pct > 95) pct = 95;
            s_ota_progress_pct = pct;
        }
    }

    free(buf);
    esp_http_client_close(client);
    esp_http_client_cleanup(client);

    if (ok && total_written == 0) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Downloaded empty firmware binary");
        ok = false;
    }

    if (ok && check_sha) {
        s_ota_state = EH_OTA_STATE_VERIFYING;
        uint8_t digest[32];
        char hex_digest[65];
        mbedtls_sha256_finish(&sha_ctx, digest);
        for (int i = 0; i < 32; i++) {
            sprintf(hex_digest + (i * 2), "%02x", digest[i]);
        }
        hex_digest[64] = '\0';
        if (strcasecmp(hex_digest, manifest->sha256) != 0) {
            snprintf(s_ota_last_error, sizeof(s_ota_last_error), "SHA-256 checksum mismatch");
            ESP_LOGE(TAG, "SHA-256 mismatch: expected %s, got %s", manifest->sha256, hex_digest);
            ok = false;
        }
    }
    if (check_sha) {
        mbedtls_sha256_free(&sha_ctx);
    }

    if (!ok) {
        esp_ota_abort(update_handle);
        return false;
    }

    err = esp_ota_end(update_handle);
    if (err != ESP_OK) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "esp_ota_end failed: %s", esp_err_to_name(err));
        ESP_LOGE(TAG, "%s", s_ota_last_error);
        return false;
    }

    err = esp_ota_set_boot_partition(update_partition);
    if (err != ESP_OK) {
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "set_boot_partition failed: %s", esp_err_to_name(err));
        ESP_LOGE(TAG, "%s", s_ota_last_error);
        return false;
    }

    s_ota_progress_pct = 100;
    return true;
}
#endif

bool ota_manager_start_update(const eh_ota_manifest_t* manifest)
{
    s_ota_last_error[0] = '\0';
    s_ota_progress_pct = 5;
    if (!ota_validate_manifest(manifest, EH_FIRMWARE_VERSION)) {
        s_ota_state = EH_OTA_STATE_FAILED;
        return false;
    }

    s_ota_state = EH_OTA_STATE_DOWNLOADING;
    status_led_set_pattern(STATUS_LED_OTA_UPDATING);
    app_lifecycle_set_state(APP_STATE_OTA_UPDATING);
    ESP_LOGI(TAG, "Starting OTA update to version %s from %s (size: %u bytes)",
             manifest->version, manifest->download_url, (unsigned int)manifest->binary_size_bytes);

#ifdef ESP_PLATFORM
    bool ok = false;
    if (strncmp(manifest->download_url, "http://", 7) == 0) {
        ok = run_http_streaming_ota(manifest);
    } else {
        esp_http_client_config_t http_config = {
            .url = manifest->download_url,
            .timeout_ms = 15000,
            .keep_alive_enable = true,
        };
        esp_https_ota_config_t ota_config = {
            .http_config = &http_config,
        };
        s_ota_state = EH_OTA_STATE_INSTALLING;
        s_ota_progress_pct = 50;
        esp_err_t ret = esp_https_ota(&ota_config);
        if (ret == ESP_OK) {
            s_ota_progress_pct = 100;
            ok = true;
        } else {
            snprintf(s_ota_last_error, sizeof(s_ota_last_error), "HTTPS OTA failed: %s", esp_err_to_name(ret));
        }
    }

    if (ok) {
        s_ota_state = EH_OTA_STATE_REBOOTING;
        ESP_LOGI(TAG, "OTA update successful! Rebooting into new firmware...");
        vTaskDelay(pdMS_TO_TICKS(800));
        esp_restart();
        return true;
    } else {
        s_ota_state = EH_OTA_STATE_FAILED;
        status_led_set_pattern(STATUS_LED_SOLID_ON);
        app_lifecycle_set_state(APP_STATE_LOCAL_OPERATIONAL);
        ESP_LOGE(TAG, "OTA update failed: %s", s_ota_last_error);
        return false;
    }
#else
    s_ota_progress_pct = 100;
    s_ota_state = EH_OTA_STATE_REBOOTING;
    return true;
#endif
}

#ifdef ESP_PLATFORM
static void ota_worker_task(void* arg)
{
    (void)arg;
    ota_manager_start_update(&s_pending_manifest);
    s_ota_task_running = false;
    vTaskDelete(NULL);
}
#endif

bool ota_manager_start_update_async(const eh_ota_manifest_t* manifest)
{
    if (!manifest || s_ota_task_running) {
        return false;
    }
    if (!ota_validate_manifest(manifest, EH_FIRMWARE_VERSION)) {
        s_ota_state = EH_OTA_STATE_FAILED;
        return false;
    }
    memcpy(&s_pending_manifest, manifest, sizeof(eh_ota_manifest_t));
#ifdef ESP_PLATFORM
    s_ota_task_running = true;
    if (xTaskCreate(ota_worker_task, "eh_ota_task", 8192, NULL, 5, NULL) != pdPASS) {
        s_ota_task_running = false;
        snprintf(s_ota_last_error, sizeof(s_ota_last_error), "Failed to allocate OTA task");
        s_ota_state = EH_OTA_STATE_FAILED;
        return false;
    }
    return true;
#else
    return ota_manager_start_update(&s_pending_manifest);
#endif
}
