#ifndef EH_BOARD_PINOUT_H
#define EH_BOARD_PINOUT_H

#ifdef ESP_PLATFORM
#include "sdkconfig.h"
#endif

// ==============================================================================
// Target A: ESP32-D0WD-V3 (CONFIG_IDF_TARGET_ESP32 — Active Development Board)
// ==============================================================================
#if defined(CONFIG_IDF_TARGET_ESP32)

// Relays 1–4 (Glitch-Free Digital Outputs)
#define EH_PIN_RELAY_1 18
#define EH_PIN_RELAY_2 19
#define EH_PIN_RELAY_3 21
#define EH_PIN_RELAY_4 22

// Physical Wall Switches 1–4 (100% Non-Strapping Inputs, Active-LOW with Internal Pull-Up)
#define EH_PIN_SWITCH_1 23
#define EH_PIN_SWITCH_2 25
#define EH_PIN_SWITCH_3 26
#define EH_PIN_SWITCH_4 27

// BL0942 Energy Metering UART2 (EH-SW4X-EM)
#define EH_PIN_BL0942_TX 17
#define EH_PIN_BL0942_RX 16
#define BL0942_UART_PORT 2

// System Controls (Non-Strapping Primary Pins)
#define EH_PIN_BUTTON_RESET           33  // Primary safe production pin (100% non-strapping)
#define EH_PIN_BUTTON_RESET_SECONDARY  0  // Secondary DevKit convenience BOOT button
#define EH_PIN_STATUS_LED             13  // Primary non-strapping pin
#define EH_PIN_STATUS_LED_SECONDARY    2  // Secondary DevKit onboard LED

// ==============================================================================
// Target B: ESP32-C6-WROOM-1 (CONFIG_IDF_TARGET_ESP32C6 — Commercial Production PCB)
// ==============================================================================
#elif defined(CONFIG_IDF_TARGET_ESP32C6)

// Relays 1–4 (Designed for external 2.2k pull-downs overcoming 45k reset WPU)
#define EH_PIN_RELAY_1 0
#define EH_PIN_RELAY_2 1
#define EH_PIN_RELAY_3 2
#define EH_PIN_RELAY_4 3

// Physical Wall Switches 1–4 (Non-Strapping Inputs)
#define EH_PIN_SWITCH_1 18
#define EH_PIN_SWITCH_2 19
#define EH_PIN_SWITCH_3 20
#define EH_PIN_SWITCH_4 21

// BL0942 Energy Metering UART1 (Avoids UART0 boot ROM pins GPIO 16, 17)
#define EH_PIN_BL0942_TX 6
#define EH_PIN_BL0942_RX 7
#define BL0942_UART_PORT 1

// Commissioning / Factory Reset Button (Non-Strapping, GPIO 9 strictly reserved for PCB flashing header)
#define EH_PIN_BUTTON_RESET 10

// Status LED (Non-Strapping)
#define EH_PIN_STATUS_LED 22

// Reserved Pins:
// UART0 Flashing/Debug: GPIO 16, 17
// Native USB Serial/JTAG: GPIO 12, 13

// ==============================================================================
// Host Simulation / Fallback Profile
// ==============================================================================
#else

#define EH_PIN_RELAY_1 18
#define EH_PIN_RELAY_2 19
#define EH_PIN_RELAY_3 21
#define EH_PIN_RELAY_4 22

#define EH_PIN_SWITCH_1 23
#define EH_PIN_SWITCH_2 25
#define EH_PIN_SWITCH_3 26
#define EH_PIN_SWITCH_4 27

#define EH_PIN_BL0942_TX 17
#define EH_PIN_BL0942_RX 16
#define BL0942_UART_PORT 2

#define EH_PIN_BUTTON_RESET           33
#define EH_PIN_BUTTON_RESET_SECONDARY  0
#define EH_PIN_STATUS_LED             13
#define EH_PIN_STATUS_LED_SECONDARY    2

#endif

// Canonical Compatibility Aliases
#define GPIO_RELAY_CH1 EH_PIN_RELAY_1
#define GPIO_RELAY_CH2 EH_PIN_RELAY_2
#define GPIO_RELAY_CH3 EH_PIN_RELAY_3
#define GPIO_RELAY_CH4 EH_PIN_RELAY_4

#define GPIO_SWITCH_IN_CH1 EH_PIN_SWITCH_1
#define GPIO_SWITCH_IN_CH2 EH_PIN_SWITCH_2
#define GPIO_SWITCH_IN_CH3 EH_PIN_SWITCH_3
#define GPIO_SWITCH_IN_CH4 EH_PIN_SWITCH_4

#define GPIO_STATUS_LED    EH_PIN_STATUS_LED
#define GPIO_RESET_BUTTON  EH_PIN_BUTTON_RESET

#endif /* EH_BOARD_PINOUT_H */
