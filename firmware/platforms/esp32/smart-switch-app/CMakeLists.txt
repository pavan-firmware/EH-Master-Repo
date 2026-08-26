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
