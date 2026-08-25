idf_component_register(
    SRCS "eh_prov1.c"
    INCLUDE_DIRS "."
    REQUIRES factory_identity_v2 mbedtls esp_system log
)
