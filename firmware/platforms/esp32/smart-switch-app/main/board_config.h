#ifndef EH_BOARD_CONFIG_H
#define EH_BOARD_CONFIG_H

#ifdef ESP_PLATFORM
#include "sdkconfig.h"
#endif

#include "board_pinout.h"

// Canonical Relay Channel Count
#ifndef EH_RELAY_CHANNEL_COUNT
#ifdef CONFIG_EH_CHANNEL_COUNT
#define EH_RELAY_CHANNEL_COUNT CONFIG_EH_CHANNEL_COUNT
#else
#define EH_RELAY_CHANNEL_COUNT 4
#endif
#endif

// Canonical Physical Switch Channel Count
#ifndef EH_SWITCH_CHANNEL_COUNT
#ifdef CONFIG_EH_CHANNEL_COUNT
#define EH_SWITCH_CHANNEL_COUNT CONFIG_EH_CHANNEL_COUNT
#else
#define EH_SWITCH_CHANNEL_COUNT EH_RELAY_CHANNEL_COUNT
#endif
#endif

// Energy Metering Feature Flag
#ifndef EH_FEATURE_ENERGY_MONITORING
#if defined(CONFIG_EH_ENERGY_METERING_ENABLED)
#define EH_FEATURE_ENERGY_MONITORING 1
#else
#define EH_FEATURE_ENERGY_MONITORING 0
#endif
#endif

// Product Type Classification
#ifndef EH_PRODUCT_TYPE
#ifdef CONFIG_EH_PRODUCT_TYPE
#define EH_PRODUCT_TYPE CONFIG_EH_PRODUCT_TYPE
#else
#define EH_PRODUCT_TYPE "SMART_SWITCH"
#endif
#endif

// Variant String Identifier
#ifndef EH_PRODUCT_VARIANT
#ifdef CONFIG_EH_PRODUCT_VARIANT
#define EH_PRODUCT_VARIANT CONFIG_EH_PRODUCT_VARIANT
#else
#if EH_RELAY_CHANNEL_COUNT == 1
#define EH_PRODUCT_VARIANT "1X"
#elif EH_RELAY_CHANNEL_COUNT == 2
#define EH_PRODUCT_VARIANT "2X"
#elif EH_RELAY_CHANNEL_COUNT == 3
#define EH_PRODUCT_VARIANT "3X"
#else
#define EH_PRODUCT_VARIANT "4X"
#endif
#endif
#endif

// Deterministic Model Name Derivation
#ifndef EH_MODEL_NAME
#ifdef CONFIG_EH_MODEL_NAME
#define EH_MODEL_NAME CONFIG_EH_MODEL_NAME
#elif defined(CONFIG_EH_PRODUCT_TYPE_SOCKET) || defined(EH_IS_SOCKET)
#if EH_RELAY_CHANNEL_COUNT == 1
#define EH_MODEL_NAME "EH-SK-1X"
#elif EH_RELAY_CHANNEL_COUNT == 2
#define EH_MODEL_NAME "EH-SK-2X"
#else
#define EH_MODEL_NAME "EH-SK-3X"
#endif
#else
#if EH_FEATURE_ENERGY_MONITORING
#define EH_MODEL_NAME "EH-SW4X-EM"
#elif EH_RELAY_CHANNEL_COUNT == 1
#define EH_MODEL_NAME "EH-SW-1X"
#elif EH_RELAY_CHANNEL_COUNT == 2
#define EH_MODEL_NAME "EH-SW-2X"
#elif EH_RELAY_CHANNEL_COUNT == 3
#define EH_MODEL_NAME "EH-SW-3X"
#else
#define EH_MODEL_NAME "EH-SW-4X"
#endif
#endif
#endif

#endif /* EH_BOARD_CONFIG_H */
