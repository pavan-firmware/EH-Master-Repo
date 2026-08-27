#include "telemetry_manager.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "driver/uart.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#define TAG "TELEMETRY_MGR"
#else
#define TAG "TELEMETRY_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

// BL0942 Conversion Constants (Standard 1mOhm shunt + 1M/1K divider)
#define V_REF_SCALE 7398.9f    // V_RMS raw / V_REF_SCALE = Volts (fits 24-bit register)
#define I_REF_SCALE 30597.8f   // I_RMS raw / I_REF_SCALE = Amperes
#define W_REF_SCALE 353.7f     // WATT raw / W_REF_SCALE = Watts
#define E_PULSE_SCALE 163.84f  // CF_CNT / E_PULSE_SCALE = kWh

static telemetry_data_cb_t s_data_cb = NULL;

bool telemetry_parse_bl0942_frame(const uint8_t* frame, size_t len, bl0942_data_t* out_data)
{
    if (!frame || len < BL0942_FRAME_LEN || !out_data) {
        return false;
    }

    if (frame[0] != 0x55) {
        return false; // Invalid header
    }

    // Checksum calculation: ~sum(frame[0..21]) & 0xFF
    uint8_t sum = 0;
    for (size_t i = 0; i < BL0942_FRAME_LEN - 1; i++) {
        sum += frame[i];
    }
    uint8_t expected_checksum = (uint8_t)(~sum);

    if (frame[BL0942_FRAME_LEN - 1] != expected_checksum) {
        ESP_LOGW(TAG, "BL0942 checksum mismatch: got 0x%02X, expected 0x%02X",
                 frame[BL0942_FRAME_LEN - 1], expected_checksum);
        out_data->valid = false;
        return false;
    }

    // Extract 24-bit little-endian fields
    uint32_t i_raw = (uint32_t)frame[1] | ((uint32_t)frame[2] << 8) | ((uint32_t)frame[3] << 16);
    uint32_t v_raw = (uint32_t)frame[4] | ((uint32_t)frame[5] << 8) | ((uint32_t)frame[6] << 16);
    int32_t  p_raw = (int32_t)((uint32_t)frame[10] | ((uint32_t)frame[11] << 8) | ((uint32_t)frame[12] << 16));
    // Sign-extend 24-bit power
    if (p_raw & 0x800000) {
        p_raw |= 0xFF000000;
    }
    uint32_t e_raw = (uint32_t)frame[13] | ((uint32_t)frame[14] << 8) | ((uint32_t)frame[15] << 16);
    uint32_t f_raw = (uint32_t)frame[16] | ((uint32_t)frame[17] << 8);

    // Convert to fixed point
    float v_volts = (float)v_raw / V_REF_SCALE;
    float i_amps = (float)i_raw / I_REF_SCALE;
    float p_watts = (float)p_raw / W_REF_SCALE;
    float e_kwh = (float)e_raw / E_PULSE_SCALE;

    out_data->voltage_mv = (uint32_t)(v_volts * 1000.0f);
    out_data->current_ma = (uint32_t)(i_amps * 1000.0f);
    out_data->power_mw = (int32_t)(p_watts * 1000.0f);
    out_data->energy_tot_wh = (uint32_t)(e_kwh * 1000.0f);
    out_data->frequency_mhz = (f_raw > 0) ? (500000000 / f_raw) : 50000;
    out_data->valid = true;

    return true;
}

#ifdef ESP_PLATFORM
static void telemetry_task(void* arg)
{
    uint8_t rx_buf[128];
    bl0942_data_t data;

    while (1) {
        // BL0942 sends 23-byte packet periodically
        int len = uart_read_bytes(BL0942_UART_PORT, rx_buf, sizeof(rx_buf), pdMS_TO_TICKS(1000));
        if (len >= BL0942_FRAME_LEN) {
            // Find 0x55 header
            for (int i = 0; i <= len - BL0942_FRAME_LEN; i++) {
                if (rx_buf[i] == 0x55) {
                    if (telemetry_parse_bl0942_frame(&rx_buf[i], BL0942_FRAME_LEN, &data)) {
                        if (s_data_cb) {
                            s_data_cb(&data);
                        }
                        break;
                    }
                }
            }
        }
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}
#endif

void telemetry_manager_init(void)
{
#ifdef ESP_PLATFORM
    uart_config_t uart_config = {
        .baud_rate = BL0942_BAUD_RATE,
        .data_bits = UART_DATA_8_BITS,
        .parity    = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE
    };
    uart_param_config(BL0942_UART_PORT, &uart_config);
#if defined(CONFIG_IDF_TARGET_ESP32)
    // ESP32-D0WD Development Board: UART1 TX=17, RX=16
    uart_set_pin(BL0942_UART_PORT, 17, 16, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
#else
    // ESP32-C6 Production: UART1 RX=7
    uart_set_pin(BL0942_UART_PORT, UART_PIN_NO_CHANGE, 7, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
#endif
    uart_driver_install(BL0942_UART_PORT, 256, 0, 0, NULL, 0);

    xTaskCreate(telemetry_task, "telemetry_task", 3072, NULL, 5, NULL);
#endif
    ESP_LOGI(TAG, "BL0942 telemetry driver initialized on UART%d @ %d baud", BL0942_UART_PORT, BL0942_BAUD_RATE);
}

void telemetry_manager_register_cb(telemetry_data_cb_t cb)
{
    s_data_cb = cb;
}
