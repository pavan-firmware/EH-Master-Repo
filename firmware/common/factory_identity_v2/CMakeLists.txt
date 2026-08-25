idf_component_register(
    SRCS "factory_identity_v2.c"
    INCLUDE_DIRS "."
    REQUIRES nvs_flash esp_system log
)
