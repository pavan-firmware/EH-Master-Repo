idf_component_register(
    SRCS "ble_commissioning.c"
    INCLUDE_DIRS "."
    REQUIRES eh_prov1 factory_identity_v2 bt nimble log
)
