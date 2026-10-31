#include "edge_routine_engine.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/timers.h"
#include "nvs_flash.h"
#include "nvs.h"
#define TAG "EDGE_ROUTINE"
#define NVS_ROUTINES_NAMESPACE "eh_routines"
#define NVS_ROUTINES_KEY "tbl_v1"
#else
#define TAG "EDGE_ROUTINE"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

#include "cJSON.h"
#include "relay_manager.h"
#include "time_sync_manager.h"

// Compact serialized configuration for NVS flash storage (zero transient runtime fields)
typedef struct {
    char id[ROUTINE_ID_MAX_LEN];
    char name[ROUTINE_NAME_MAX_LEN];
    uint8_t channel_index;
    bool target_power;
    uint8_t trigger_type;
    uint32_t duration_sec;
    uint8_t hour;
    uint8_t minute;
    uint8_t days_mask;
    bool enabled;
    uint8_t is_toggle;
    uint8_t valid;
} edge_routine_persist_t;

typedef struct {
    uint32_t version;
    uint32_t count;
    edge_routine_persist_t items[MAX_EDGE_ROUTINES];
} edge_routine_nvs_blob_t;

static edge_routine_t s_routines[MAX_EDGE_ROUTINES];
static size_t s_routine_count = 0;
static bool s_initialized = false;

#ifdef ESP_PLATFORM
static TimerHandle_t s_tick_timer = NULL;
#endif

// Forward declaration
static void routine_tick_timer_cb(void* arg);
static bool save_table_to_nvs_wear_leveled(void);
static void load_table_from_nvs(void);

void edge_routine_engine_init(void)
{
    if (s_initialized) return;

    memset(s_routines, 0, sizeof(s_routines));
    s_routine_count = 0;

    // 1. Wear-Leveling Step 1: Read routines from NVS into RAM exactly ONCE on boot
    load_table_from_nvs();

#ifdef ESP_PLATFORM
    // 2. Start 1-second FreeRTOS software timer for purely in-RAM execution
    s_tick_timer = xTimerCreate("edge_rt_tmr", pdMS_TO_TICKS(1000), pdTRUE, NULL, (TimerCallbackFunction_t)routine_tick_timer_cb);
    if (s_tick_timer) {
        xTimerStart(s_tick_timer, 0);
    }
#endif

    s_initialized = true;
    ESP_LOGI(TAG, "Edge Routine Engine initialized. Loaded %u routines into RAM.", (unsigned int)s_routine_count);
}

void edge_routine_engine_deinit(void)
{
#ifdef ESP_PLATFORM
    if (s_tick_timer) {
        xTimerStop(s_tick_timer, 0);
        xTimerDelete(s_tick_timer, 0);
        s_tick_timer = NULL;
    }
#endif
    s_initialized = false;
}

static void routine_tick_timer_cb(void* arg)
{
    (void)arg;
    time_sync_manager_tick();

    time_t now_time = time(NULL);
    struct tm timeinfo;
    localtime_r(&now_time, &timeinfo);
    bool time_synced = time_sync_manager_is_synced();

    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        edge_routine_t* r = &s_routines[i];
        if (r->id[0] == '\0' || !r->enabled) continue;

        // 1. In-flight countdown timer ticking (Strictly in RAM - zero flash writes)
        // Works immediately without requiring time sync (relative seconds)
        if (r->runtime_state == ROUTINE_STATE_RUNNING) {
            if (r->remaining_sec > 0) {
                r->remaining_sec--;
                if (r->remaining_sec == 0) {
                    // Timer expired: perform pulse completion (e.g. auto-off after motor runtime)
                    ESP_LOGI(TAG, "Routine [%s] duration elapsed. Restoring opposite power on CH%d (is_toggle=%d)",
                             r->name, r->channel_index, r->is_toggle);
                    if (r->is_toggle) {
                        relay_manager_toggle_power(r->channel_index, "EDGE_ROUTINE_AUTO_OFF");
                    } else {
                        relay_manager_set_power(r->channel_index, !r->target_power, "EDGE_ROUTINE_AUTO_OFF");
                    }
                    r->runtime_state = ROUTINE_STATE_COMPLETED;
                }
            }
        }

        // 2. Schedule trigger evaluation (Runs once per day at target hour:minute)
        // Strictly gated by time_synced to eliminate false triggers on epoch 1970
        if (r->trigger_type == EDGE_TRIGGER_SCHEDULE) {
            if (!time_synced) {
                // Clock is invalid (1970). Hold schedule evaluation to protect physical loads.
                continue;
            }
            if (timeinfo.tm_hour == r->hour && timeinfo.tm_min == r->minute) {
                uint8_t current_day_bit = (1 << timeinfo.tm_wday);
                if ((r->days_mask & current_day_bit) != 0) {
                    if (r->last_triggered_min != timeinfo.tm_min && r->runtime_state != ROUTINE_STATE_RUNNING) {
                        r->last_triggered_min = timeinfo.tm_min;
                        ESP_LOGI(TAG, "Scheduled routine [%s] triggering on CH%d at %02d:%02d (duration=%u s, toggle=%d)",
                                 r->name, r->channel_index, r->hour, r->minute, (unsigned int)r->duration_sec, r->is_toggle);
                        edge_routine_engine_start_routine(r->id);
                    }
                }
            } else {
                // Minute has elapsed: disarm minute guard and reset COMPLETED/STOPPED back to IDLE
                if (r->last_triggered_min == r->minute) {
                    r->last_triggered_min = 255;
                }
                if (r->runtime_state == ROUTINE_STATE_COMPLETED || r->runtime_state == ROUTINE_STATE_STOPPED) {
                    r->runtime_state = ROUTINE_STATE_IDLE;
                }
            }
        }
    }
}

/**
 * Dual Emergency Stop handler:
 * Instantly stops/disarms active timers and routines in RAM without writing to flash.
 */
void edge_routine_engine_emergency_stop(uint8_t channel_index, const char* reason)
{
    uint32_t stopped_count = 0;
    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        edge_routine_t* r = &s_routines[i];
        if (r->id[0] == '\0') continue;

        if (channel_index == 0 || r->channel_index == channel_index) {
            if (r->runtime_state == ROUTINE_STATE_RUNNING) {
                r->runtime_state = ROUTINE_STATE_STOPPED;
                r->remaining_sec = 0;
                stopped_count++;
                ESP_LOGW(TAG, "EMERGENCY_STOP: Routine '%s' (CH%d) aborted instantly. Reason: %s",
                         r->name, r->channel_index, reason ? reason : "UNKNOWN");
            }
        }
    }
    if (stopped_count > 0) {
        ESP_LOGW(TAG, "Dual Emergency Stop complete: %u active routine(s) disarmed.", (unsigned int)stopped_count);
    }
}

bool edge_routine_engine_start_routine(const char* routine_id)
{
    if (!routine_id) return false;

    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        edge_routine_t* r = &s_routines[i];
        if (strcmp(r->id, routine_id) == 0) {
            // Apply initial target power or toggle
            bool ok;
            if (r->is_toggle) {
                ok = relay_manager_toggle_power(r->channel_index, "EDGE_ROUTINE_TOGGLE");
            } else {
                ok = relay_manager_set_power(r->channel_index, r->target_power, "EDGE_ROUTINE");
            }
            if (!ok) return false;

            if (r->duration_sec > 0) {
                r->remaining_sec = r->duration_sec;
                r->runtime_state = ROUTINE_STATE_RUNNING;
                ESP_LOGI(TAG, "Started routine [%s] on CH%d for %u seconds (toggle=%d)",
                         r->name, r->channel_index, (unsigned int)r->duration_sec, r->is_toggle);
            } else {
                r->runtime_state = ROUTINE_STATE_COMPLETED;
            }
            return true;
        }
    }
    return false;
}

bool edge_routine_engine_upsert_routine(const edge_routine_t* routine)
{
    if (!routine || routine->id[0] == '\0' || routine->channel_index < 1 || routine->channel_index > EH_RELAY_CHANNEL_COUNT) {
        return false;
    }

    int target_idx = -1;
    // 1. Look for existing routine with same ID
    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        if (strcmp(s_routines[i].id, routine->id) == 0) {
            target_idx = (int)i;
            break;
        }
    }

    // 2. If not found, look for empty slot
    if (target_idx < 0) {
        for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
            if (s_routines[i].id[0] == '\0') {
                target_idx = (int)i;
                break;
            }
        }
    }

    if (target_idx < 0) {
        ESP_LOGE(TAG, "Routine table full (max %d routines)", MAX_EDGE_ROUTINES);
        return false;
    }

    // Update in-memory routine
    s_routines[target_idx] = *routine;
    s_routines[target_idx].runtime_state = ROUTINE_STATE_IDLE;
    s_routines[target_idx].remaining_sec = 0;
    s_routines[target_idx].last_triggered_min = 255;

    // Recalculate active routine count
    size_t count = 0;
    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        if (s_routines[i].id[0] != '\0') count++;
    }
    s_routine_count = count;

    // 3. Wear-leveling write to NVS only when config modified
    return save_table_to_nvs_wear_leveled();
}

bool edge_routine_engine_delete_routine(const char* routine_id)
{
    if (!routine_id) return false;

    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        if (strcmp(s_routines[i].id, routine_id) == 0) {
            // Disarm before deleting
            if (s_routines[i].runtime_state == ROUTINE_STATE_RUNNING) {
                s_routines[i].runtime_state = ROUTINE_STATE_STOPPED;
                s_routines[i].remaining_sec = 0;
            }
            memset(&s_routines[i], 0, sizeof(edge_routine_t));

            size_t count = 0;
            for (size_t j = 0; j < MAX_EDGE_ROUTINES; j++) {
                if (s_routines[j].id[0] != '\0') count++;
            }
            s_routine_count = count;

            return save_table_to_nvs_wear_leveled();
        }
    }
    return false;
}

const edge_routine_t* edge_routine_engine_get_routines(size_t* out_count)
{
    if (out_count) *out_count = s_routine_count;
    return s_routines;
}

static void load_table_from_nvs(void)
{
#ifdef ESP_PLATFORM
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_ROUTINES_NAMESPACE, NVS_READONLY, &handle);
    if (err != ESP_OK) {
        ESP_LOGI(TAG, "No existing routine table in NVS (starting fresh)");
        return;
    }

    edge_routine_nvs_blob_t blob;
    size_t required_size = sizeof(blob);
    err = nvs_get_blob(handle, NVS_ROUTINES_KEY, &blob, &required_size);
    nvs_close(handle);

    if (err != ESP_OK || (blob.version != 1 && blob.version != 2)) {
        ESP_LOGW(TAG, "Failed to read routine blob from NVS or invalid version: %s", esp_err_to_name(err));
        return;
    }

    s_routine_count = 0;
    for (size_t i = 0; i < MAX_EDGE_ROUTINES && i < blob.count; i++) {
        if (blob.items[i].valid && blob.items[i].id[0] != '\0') {
            edge_routine_t* r = &s_routines[i];
            strncpy(r->id, blob.items[i].id, ROUTINE_ID_MAX_LEN - 1);
            strncpy(r->name, blob.items[i].name, ROUTINE_NAME_MAX_LEN - 1);
            r->channel_index = blob.items[i].channel_index;
            r->target_power = blob.items[i].target_power;
            r->is_toggle = (blob.version >= 2) ? (blob.items[i].is_toggle != 0) : false;
            r->trigger_type = (edge_trigger_type_t)blob.items[i].trigger_type;
            r->duration_sec = blob.items[i].duration_sec;
            r->hour = blob.items[i].hour;
            r->minute = blob.items[i].minute;
            r->days_mask = blob.items[i].days_mask;
            r->enabled = blob.items[i].enabled;
            r->runtime_state = ROUTINE_STATE_IDLE;
            r->remaining_sec = 0;
            r->last_triggered_min = 255;
            s_routine_count++;
        }
    }
    ESP_LOGI(TAG, "NVS: Successfully loaded %u routines from flash into RAM", (unsigned int)s_routine_count);
#endif
}

/**
 * Professional wear-leveling NVS commit:
 * Reads existing flash blob and performs bitwise memcmp.
 * If data is unchanged, completely skips erase/write cycle to protect flash endurance.
 */
static bool save_table_to_nvs_wear_leveled(void)
{
#ifdef ESP_PLATFORM
    edge_routine_nvs_blob_t new_blob;
    memset(&new_blob, 0, sizeof(new_blob));
    new_blob.version = 2;
    new_blob.count = MAX_EDGE_ROUTINES;

    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        if (s_routines[i].id[0] != '\0') {
            edge_routine_persist_t* p = &new_blob.items[i];
            strncpy(p->id, s_routines[i].id, ROUTINE_ID_MAX_LEN - 1);
            strncpy(p->name, s_routines[i].name, ROUTINE_NAME_MAX_LEN - 1);
            p->channel_index = s_routines[i].channel_index;
            p->target_power = s_routines[i].target_power;
            p->is_toggle = s_routines[i].is_toggle ? 1 : 0;
            p->trigger_type = (uint8_t)s_routines[i].trigger_type;
            p->duration_sec = s_routines[i].duration_sec;
            p->hour = s_routines[i].hour;
            p->minute = s_routines[i].minute;
            p->days_mask = s_routines[i].days_mask;
            p->enabled = s_routines[i].enabled;
            p->valid = 1;
        }
    }

    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_ROUTINES_NAMESPACE, NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to open NVS for writing routines: %s", esp_err_to_name(err));
        return false;
    }

    // Wear-leveling check: Read current blob to compare
    edge_routine_nvs_blob_t current_blob;
    size_t cur_len = sizeof(current_blob);
    err = nvs_get_blob(handle, NVS_ROUTINES_KEY, &current_blob, &cur_len);
    if (err == ESP_OK && cur_len == sizeof(new_blob) && memcmp(&current_blob, &new_blob, sizeof(new_blob)) == 0) {
        ESP_LOGI(TAG, "Wear-Leveling: Routine table identical to flash. NVS write skipped.");
        nvs_close(handle);
        return true;
    }

    // Perform actual write
    err = nvs_set_blob(handle, NVS_ROUTINES_KEY, &new_blob, sizeof(new_blob));
    if (err == ESP_OK) {
        err = nvs_commit(handle);
        ESP_LOGI(TAG, "Wear-Leveling: Routine table committed to NVS flash successfully.");
    } else {
        ESP_LOGE(TAG, "Failed to set NVS blob: %s", esp_err_to_name(err));
    }
    nvs_close(handle);
    return (err == ESP_OK);
#else
    return true;
#endif
}

char* edge_routine_engine_to_json_string(void)
{
    cJSON* root = cJSON_CreateArray();
    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
        const edge_routine_t* r = &s_routines[i];
        if (r->id[0] == '\0') continue;

        cJSON* item = cJSON_CreateObject();
        cJSON_AddStringToObject(item, "id", r->id);
        cJSON_AddStringToObject(item, "name", r->name);
        cJSON_AddNumberToObject(item, "channelIndex", r->channel_index);
        cJSON_AddBoolToObject(item, "targetPower", r->target_power);
        cJSON_AddBoolToObject(item, "isToggle", r->is_toggle);
        cJSON_AddNumberToObject(item, "triggerType", r->trigger_type);
        cJSON_AddNumberToObject(item, "durationSec", r->duration_sec);
        cJSON_AddNumberToObject(item, "hour", r->hour);
        cJSON_AddNumberToObject(item, "minute", r->minute);
        cJSON_AddNumberToObject(item, "daysMask", r->days_mask);
        cJSON_AddBoolToObject(item, "enabled", r->enabled);

        const char* state_str = "IDLE";
        if (r->runtime_state == ROUTINE_STATE_RUNNING) state_str = "RUNNING";
        else if (r->runtime_state == ROUTINE_STATE_STOPPED) state_str = "STOPPED";
        else if (r->runtime_state == ROUTINE_STATE_COMPLETED) state_str = "COMPLETED";

        cJSON_AddStringToObject(item, "state", state_str);
        cJSON_AddNumberToObject(item, "remainingSec", r->remaining_sec);

        cJSON_AddItemToArray(root, item);
    }

    char* rendered = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    return rendered;
}
