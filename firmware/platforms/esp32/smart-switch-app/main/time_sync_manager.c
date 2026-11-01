#include "time_sync_manager.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/time.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_sntp.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#define TAG "TIME_SYNC"
#else
#define TAG "TIME_SYNC"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)

#ifdef _WIN32
static inline int setenv(const char *name, const char *value, int overwrite) {
    (void)overwrite;
    return _putenv_s(name, value);
}
static inline struct tm *localtime_r(const time_t *timep, struct tm *result) {
    localtime_s(result, timep);
    return result;
}
static inline int settimeofday(const struct timeval *tv, const void *tz) {
    (void)tv; (void)tz;
    return 0;
}
#endif
#endif

#include "wifi_manager.h"

static volatile bool s_is_time_synced = false;
static uint32_t s_last_retry_tick_sec = 0;
#ifdef ESP_PLATFORM
static bool s_sntp_initialized = false;
#endif
static char s_current_tz[32] = DEFAULT_TIMEZONE;

void time_sync_manager_init(void)
{
    s_is_time_synced = false;
    s_last_retry_tick_sec = 0;

    // Set default timezone (IST: UTC+5:30)
    time_sync_manager_set_timezone(DEFAULT_TIMEZONE);

    // Initial check: is system clock already valid (e.g. preserved across software reset)?
    time_t now = time(NULL);
    if ((uint64_t)now >= MIN_VALID_EPOCH) {
        s_is_time_synced = true;
        ESP_LOGI(TAG, "System RTC valid on boot (preserved across reset). Epoch: %lld", (long long)now);
    } else {
        s_is_time_synced = false;
        ESP_LOGW(TAG, "RTC uninitialized (epoch: %lld). Schedule execution held until time synchronized.", (long long)now);
    }
}

void time_sync_manager_start_sntp(void)
{
#ifdef ESP_PLATFORM
    if (!s_sntp_initialized) {
        esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
        esp_sntp_setservername(0, DEFAULT_NTP_SERVER_1);
        esp_sntp_setservername(1, DEFAULT_NTP_SERVER_2);
        esp_sntp_init();
        s_sntp_initialized = true;
        ESP_LOGI(TAG, "SNTP client initialized with %s, %s", DEFAULT_NTP_SERVER_1, DEFAULT_NTP_SERVER_2);
    }
#endif
}

bool time_sync_manager_is_synced(void)
{
    return s_is_time_synced;
}

time_t time_sync_manager_get_epoch(void)
{
    return time(NULL);
}

void time_sync_manager_set_timezone(const char* tz_str)
{
    if (!tz_str || strlen(tz_str) == 0) return;
    strncpy(s_current_tz, tz_str, sizeof(s_current_tz) - 1);
    s_current_tz[sizeof(s_current_tz) - 1] = '\0';
    setenv("TZ", s_current_tz, 1);
    tzset();
    ESP_LOGI(TAG, "Timezone configured: %s", s_current_tz);
}

void time_sync_manager_request_ntp_sync(void)
{
#ifdef ESP_PLATFORM
    if (s_sntp_initialized) {
        esp_sntp_stop();
        esp_sntp_init();
        ESP_LOGI(TAG, "Manual NTP synchronization triggered.");
    }
#endif
}

void time_sync_manager_tick(void)
{
    time_t now = time(NULL);

    // If unsynced, check if SNTP has successfully fetched the time in background
    if (!s_is_time_synced) {
        if ((uint64_t)now >= MIN_VALID_EPOCH) {
            s_is_time_synced = true;
            struct tm timeinfo;
            localtime_r(&now, &timeinfo);
            char strftime_buf[64];
            strftime(strftime_buf, sizeof(strftime_buf), "%Y-%m-%d %H:%M:%S", &timeinfo);
            ESP_LOGI(TAG, "NTP synchronization CONFIRMED! Local Time: %s (%s). Daily schedules ARMED.",
                     strftime_buf, s_current_tz);

#ifdef ESP_PLATFORM
            // Adjust sync interval to 24 hours (86,400,000 ms) to conserve network & energy
            esp_sntp_set_sync_interval(24 * 3600 * 1000);
#endif
            return;
        }

        // Non-blocking retry heartbeat every 15 seconds if Wi-Fi is connected
        uint32_t current_sec = (uint32_t)(now);
        if (current_sec - s_last_retry_tick_sec >= 15) {
            s_last_retry_tick_sec = current_sec;
            if (wifi_manager_is_connected()) {
                ESP_LOGI(TAG, "Waiting for NTP sync (Wi-Fi connected, awaiting NTP packet)...");
#ifdef ESP_PLATFORM
                // Re-trigger restart of sntp poll if stalled
                if (s_sntp_initialized) {
                    esp_sntp_restart();
                }
#endif
            } else {
                ESP_LOGI(TAG, "Waiting for Wi-Fi to establish NTP connection...");
            }
        }
    }
}

bool time_sync_manager_inject_epoch(uint64_t unix_sec, const char* source)
{
    if (unix_sec < MIN_VALID_EPOCH) {
        ESP_LOGW(TAG, "Rejected epoch injection: %llu is before 2025-01-01 (source: %s)",
                 (unsigned long long)unix_sec, source ? source : "UNKNOWN");
        return false;
    }

    time_t current = time(NULL);
    int64_t drift = (int64_t)current - (int64_t)unix_sec;
    if (drift < 0) drift = -drift;

    // Apply if either:
    // 1. Clock is currently un-synchronized, OR
    // 2. Drift is greater than or equal to 1 second (ensures millisecond-accurate sync with phone/network)
    if (!s_is_time_synced || drift >= 1) {
        struct timeval tv = {
            .tv_sec = (time_t)unix_sec,
            .tv_usec = 0
        };
        settimeofday(&tv, NULL);
        s_is_time_synced = true;

        struct tm timeinfo;
        time_t new_now = (time_t)unix_sec;
        localtime_r(&new_now, &timeinfo);
        char strftime_buf[64];
        strftime(strftime_buf, sizeof(strftime_buf), "%Y-%m-%d %H:%M:%S", &timeinfo);

        ESP_LOGI(TAG, "Passive RTC synchronization applied from [%s]! New Local Time: %s (drift was %llds)",
                 source ? source : "LOCAL", strftime_buf, (long long)drift);
        return true;
    }

    // Drift within acceptable tolerance (< 60s)
    return true;
}
