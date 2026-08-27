idf_component_register(
    SRCS "esp_mqtt_client_wrapper.c"
    INCLUDE_DIRS "."
    REQUIRES mqtt_transport mqtt esp_event log
)
