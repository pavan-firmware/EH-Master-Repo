idf_component_register(
    SRCS
        "main.c"
        "app_lifecycle.c"
        "wifi_manager.c"
        "relay_manager.c"
        "switch_manager.c"
        "telemetry_manager.c"
        "ota_manager.c"
        "status_led.c"
        "reset_button.c"
        "local_server.c"
        "edge_routine_engine.c"
        "time_sync_manager.c"
    INCLUDE_DIRS
        "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_event
        esp_netif
        esp_timer
        driver
        esp_driver_uart
        esp_driver_gpio
        esp_driver_gptimer
        app_update
        esp_https_ota
        esp_http_client
        esp_http_server
        mbedtls
        eh_prov1
        mqtt_transport
        factory_identity_v2
        ble_commissioning
        mqtt_client
        cjson
        lwip
)

# Determine authoritative firmware family from CMake variable, environment, or default
if(NOT DEFINED EH_FIRMWARE_FAMILY)
    if(DEFINED ENV{EH_FIRMWARE_FAMILY})
        set(EH_FIRMWARE_FAMILY "$ENV{EH_FIRMWARE_FAMILY}")
    else()
        set(EH_FIRMWARE_FAMILY "esp32c6-switch-platform")
    endif()
endif()

# Pass firmware family compile definition to main component
target_compile_definitions(${COMPONENT_LIB} PRIVATE
    EH_FIRMWARE_FAMILY="${EH_FIRMWARE_FAMILY}"
)

# Optional Variant & Channel Overrides (via -D CMake flag or Environment)
if(DEFINED EH_CHANNEL_COUNT OR DEFINED ENV{EH_CHANNEL_COUNT})
    if(DEFINED EH_CHANNEL_COUNT)
        set(VAL_CHANNEL_COUNT ${EH_CHANNEL_COUNT})
    else()
        set(VAL_CHANNEL_COUNT $ENV{EH_CHANNEL_COUNT})
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        EH_RELAY_CHANNEL_COUNT=${VAL_CHANNEL_COUNT}
        EH_SWITCH_CHANNEL_COUNT=${VAL_CHANNEL_COUNT}
    )
endif()

if(DEFINED EH_PRODUCT_TYPE OR DEFINED ENV{EH_PRODUCT_TYPE})
    if(DEFINED EH_PRODUCT_TYPE)
        set(VAL_PROD_TYPE "${EH_PRODUCT_TYPE}")
    else()
        set(VAL_PROD_TYPE "$ENV{EH_PRODUCT_TYPE}")
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        EH_PRODUCT_TYPE="${VAL_PROD_TYPE}"
    )
endif()

if(DEFINED EH_PRODUCT_VARIANT OR DEFINED ENV{EH_PRODUCT_VARIANT})
    if(DEFINED EH_PRODUCT_VARIANT)
        set(VAL_PROD_VAR "${EH_PRODUCT_VARIANT}")
    else()
        set(VAL_PROD_VAR "$ENV{EH_PRODUCT_VARIANT}")
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        EH_PRODUCT_VARIANT="${VAL_PROD_VAR}"
    )
endif()

if(DEFINED EH_MODEL_NAME OR DEFINED ENV{EH_MODEL_NAME})
    if(DEFINED EH_MODEL_NAME)
        set(VAL_MODEL_NAME "${EH_MODEL_NAME}")
    else()
        set(VAL_MODEL_NAME "$ENV{EH_MODEL_NAME}")
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        EH_MODEL_NAME="${VAL_MODEL_NAME}"
    )
endif()

# Export build-time family and target metadata to build directory
file(WRITE "${CMAKE_BINARY_DIR}/firmware_family.json"
    "{\n  \"firmwareFamily\": \"${EH_FIRMWARE_FAMILY}\",\n  \"targetMcu\": \"${CONFIG_IDF_TARGET}\",\n  \"idfTarget\": \"${CONFIG_IDF_TARGET}\"\n}\n"
)
