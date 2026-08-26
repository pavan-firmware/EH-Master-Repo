#ifndef EH_TELEMETRY_MANAGER_H
#define EH_TELEMETRY_MANAGER_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BL0942_UART_PORT 1
#define BL0942_BAUD_RATE 4800
#define BL0942_FRAME_LEN 23 // 1 header (0x55) + 21 data bytes + 1 checksum

typedef struct {
    uint32_t voltage_mv;     // Voltage in millivolts (e.g. 230000 for 230V)
    uint32_t current_ma;     // Current in milliamperes (e.g. 1500 for 1.5A)
    int32_t  power_mw;       // Active power in milliwatts (e.g. 345000 for 345W)
    uint32_t energy_tot_wh;  // Total energy in Watt-hours
    uint32_t frequency_mhz;  // Grid frequency in mHz (e.g. 50000 for 50.0Hz)
    bool     valid;
} bl0942_data_t;

typedef void (*telemetry_data_cb_t)(const bl0942_data_t* data);

/**
 * Initialize BL0942 UART driver.
 */
void telemetry_manager_init(void);

/**
 * Register callback called when a valid telemetry measurement is ready.
 */
void telemetry_manager_register_cb(telemetry_data_cb_t cb);

/**
 * Parse raw BL0942 UART frame and validate checksum.
 * Returns true if frame is valid and converted.
 */
bool telemetry_parse_bl0942_frame(const uint8_t* frame, size_t len, bl0942_data_t* out_data);

#ifdef __cplusplus
}
#endif

#endif /* EH_TELEMETRY_MANAGER_H */
