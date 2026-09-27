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
    INCLUDE_DIRS
        "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_event
        esp_netif
        esp_timer
        driver
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
        json
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

# Export build-time family metadata to build directory
file(WRITE "${CMAKE_BINARY_DIR}/firmware_family.json"
    "{\n  \"firmwareFamily\": \"${EH_FIRMWARE_FAMILY}\",\n  \"targetMcu\": \"${CONFIG_IDF_TARGET}\",\n  \"idfTarget\": \"${CONFIG_IDF_TARGET}\"\n}\n"
)
