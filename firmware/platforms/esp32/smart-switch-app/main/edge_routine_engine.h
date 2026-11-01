#ifndef EH_EDGE_ROUTINE_ENGINE_H
#define EH_EDGE_ROUTINE_ENGINE_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_EDGE_ROUTINES 16
#define ROUTINE_ID_MAX_LEN 37
#define ROUTINE_NAME_MAX_LEN 48

typedef enum {
    EDGE_TRIGGER_MANUAL = 0,
    EDGE_TRIGGER_TIMER = 1,       // Auto-off or pulse timer (duration_sec)
    EDGE_TRIGGER_SCHEDULE = 2,    // Daily clock time (hour, minute, days_mask)
} edge_trigger_type_t;

typedef enum {
    ROUTINE_STATE_IDLE = 0,
    ROUTINE_STATE_RUNNING = 1,
    ROUTINE_STATE_STOPPED = 2,
    ROUTINE_STATE_COMPLETED = 3,
} edge_routine_state_t;

typedef struct {
    char id[ROUTINE_ID_MAX_LEN];
    char name[ROUTINE_NAME_MAX_LEN];
    uint8_t channel_index;        // 1..4
    bool target_power;            // true = ON, false = OFF
    bool is_toggle;               // true = toggle current state
    edge_trigger_type_t trigger_type;
    uint32_t duration_sec;        // Pulse / auto-off duration in seconds
    uint8_t hour;                 // 0..23 for SCHEDULE
    uint8_t minute;               // 0..59 for SCHEDULE
    uint8_t days_mask;            // Bitmask (bit 0=Sun .. bit 6=Sat, 0x7F = all)
    bool enabled;
    // Runtime transient state (strictly in RAM, never written to NVS during execution)
    edge_routine_state_t runtime_state;
    uint32_t remaining_sec;
    uint8_t last_triggered_min;   // Tracks triggered minute (0..59, 255=unarmed)
} edge_routine_t;

/**
 * Initialize the Edge Routine Engine.
 * Loads persisted routines from NVS into RAM once on boot.
 * Starts background FreeRTOS timer for execution.
 */
void edge_routine_engine_init(void);

/**
 * Stop/disarm the engine and cleanup timers.
 */
void edge_routine_engine_deinit(void);

/**
 * Trigger emergency stop:
 * Immediately disarms and stops running routines.
 * @param channel_index Channel to stop (1..4), or 0 for all channels.
 * @param reason Diagnostic reason (e.g. "PHYSICAL_SWITCH", "MQTT_CLOUD", "LOCAL_HTTP").
 */
void edge_routine_engine_emergency_stop(uint8_t channel_index, const char* reason);

/**
 * Start or trigger a routine by ID.
 * Runs purely from RAM timers.
 */
bool edge_routine_engine_start_routine(const char* routine_id);

/**
 * Upsert (create or update) a routine.
 * Saves to NVS with wear-leveling dirty check.
 */
bool edge_routine_engine_upsert_routine(const edge_routine_t* routine);

/**
 * Delete a routine by ID.
 * Updates NVS table.
 */
bool edge_routine_engine_delete_routine(const char* routine_id);

/**
 * Get pointer to internal RAM routine table and count.
 */
const edge_routine_t* edge_routine_engine_get_routines(size_t* out_count);

/**
 * Serialize routines into a cJSON array or string.
 * Caller is responsible for cJSON_Delete if using cJSON helper, or buffer management.
 */
char* edge_routine_engine_to_json_string(void);

#ifdef __cplusplus
}
#endif

#endif /* EH_EDGE_ROUTINE_ENGINE_H */
