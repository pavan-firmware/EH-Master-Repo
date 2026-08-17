idf_component_register(
    SRCS
        "smart_home_node.c"
        "node_identity.c"
        "product_profile.c"
        "factory_identity.c"
        "user_configuration.c"
        "device_info.c"
        "node_protocol.c"
        "node_actuator.c"
        "ble_server.c"
    INCLUDE_DIRS "." "include"
    REQUIRES bt driver nvs_flash
)
