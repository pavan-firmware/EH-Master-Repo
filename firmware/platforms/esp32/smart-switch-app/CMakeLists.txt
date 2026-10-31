# ESP-IDF Production Application for EH Smart Switch (ESP32-C6 / ESP32-C3)
cmake_minimum_required(VERSION 3.16)

# Register common and platform component directories
set(EXTRA_COMPONENT_DIRS
    "${CMAKE_CURRENT_LIST_DIR}/../../../common/eh_prov1"
    "${CMAKE_CURRENT_LIST_DIR}/../../../common/mqtt_transport"
    "${CMAKE_CURRENT_LIST_DIR}/../../../common/factory_identity_v2"
    "${CMAKE_CURRENT_LIST_DIR}/../ble_commissioning"
    "${CMAKE_CURRENT_LIST_DIR}/../mqtt_client"
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(eh-smart-switch-app)

if(DEFINED EH_PRODUCT_TYPE OR DEFINED ENV{EH_PRODUCT_TYPE})
    if(DEFINED EH_PRODUCT_TYPE)
        set(G_PROD_TYPE "${EH_PRODUCT_TYPE}")
    else()
        set(G_PROD_TYPE "$ENV{EH_PRODUCT_TYPE}")
    endif()
    add_compile_definitions(EH_PRODUCT_TYPE="${G_PROD_TYPE}")
    idf_build_set_property(COMPILE_DEFINITIONS "-DEH_PRODUCT_TYPE=\"${G_PROD_TYPE}\"" APPEND)
    if("${G_PROD_TYPE}" MATCHES "SOCKET|socket")
        add_compile_definitions(EH_IS_SOCKET=1)
        idf_build_set_property(COMPILE_DEFINITIONS "-DEH_IS_SOCKET=1" APPEND)
    else()
        add_compile_definitions(EH_IS_SOCKET=0)
        idf_build_set_property(COMPILE_DEFINITIONS "-DEH_IS_SOCKET=0" APPEND)
    endif()
else()
    add_compile_definitions(EH_IS_SOCKET=0)
    idf_build_set_property(COMPILE_DEFINITIONS "-DEH_IS_SOCKET=0" APPEND)
endif()

if(DEFINED EH_PRODUCT_VARIANT OR DEFINED ENV{EH_PRODUCT_VARIANT})
    if(DEFINED EH_PRODUCT_VARIANT)
        set(G_PROD_VAR "${EH_PRODUCT_VARIANT}")
    else()
        set(G_PROD_VAR "$ENV{EH_PRODUCT_VARIANT}")
    endif()
    add_compile_definitions(EH_PRODUCT_VARIANT="${G_PROD_VAR}")
    idf_build_set_property(COMPILE_DEFINITIONS "-DEH_PRODUCT_VARIANT=\"${G_PROD_VAR}\"" APPEND)
endif()

if(DEFINED EH_MODEL_NAME OR DEFINED ENV{EH_MODEL_NAME})
    if(DEFINED EH_MODEL_NAME)
        set(G_MODEL_NAME "${EH_MODEL_NAME}")
    else()
        set(G_MODEL_NAME "$ENV{EH_MODEL_NAME}")
    endif()
    add_compile_definitions(EH_MODEL_NAME="${G_MODEL_NAME}")
    idf_build_set_property(COMPILE_DEFINITIONS "-DEH_MODEL_NAME=\"${G_MODEL_NAME}\"" APPEND)
endif()

if(DEFINED EH_CHANNEL_COUNT OR DEFINED ENV{EH_CHANNEL_COUNT})
    if(DEFINED EH_CHANNEL_COUNT)
        set(G_CHANNEL_COUNT ${EH_CHANNEL_COUNT})
    else()
        set(G_CHANNEL_COUNT $ENV{EH_CHANNEL_COUNT})
    endif()
    add_compile_definitions(EH_RELAY_CHANNEL_COUNT=${G_CHANNEL_COUNT})
    add_compile_definitions(EH_SWITCH_CHANNEL_COUNT=${G_CHANNEL_COUNT})
    idf_build_set_property(COMPILE_DEFINITIONS "-DEH_RELAY_CHANNEL_COUNT=${G_CHANNEL_COUNT}" APPEND)
    idf_build_set_property(COMPILE_DEFINITIONS "-DEH_SWITCH_CHANNEL_COUNT=${G_CHANNEL_COUNT}" APPEND)
endif()

