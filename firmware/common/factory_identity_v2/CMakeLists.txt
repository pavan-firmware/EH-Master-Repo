idf_component_register(
    SRCS "factory_identity_v2.c"
    INCLUDE_DIRS "."
    REQUIRES nvs_flash esp_system log
)

if(DEFINED EH_PRODUCT_TYPE OR DEFINED ENV{EH_PRODUCT_TYPE})
    if(DEFINED EH_PRODUCT_TYPE)
        set(PROD_TYPE "${EH_PRODUCT_TYPE}")
    else()
        set(PROD_TYPE "$ENV{EH_PRODUCT_TYPE}")
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE EH_PRODUCT_TYPE="${PROD_TYPE}")
    if("${PROD_TYPE}" MATCHES "SOCKET|socket")
        target_compile_definitions(${COMPONENT_LIB} PRIVATE EH_IS_SOCKET=1)
    else()
        target_compile_definitions(${COMPONENT_LIB} PRIVATE EH_IS_SOCKET=0)
    endif()
endif()

if(DEFINED EH_PRODUCT_VARIANT OR DEFINED ENV{EH_PRODUCT_VARIANT})
    if(DEFINED EH_PRODUCT_VARIANT)
        set(PROD_VAR "${EH_PRODUCT_VARIANT}")
    else()
        set(PROD_VAR "$ENV{EH_PRODUCT_VARIANT}")
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE EH_PRODUCT_VARIANT="${PROD_VAR}")
endif()

if(DEFINED EH_MODEL_NAME OR DEFINED ENV{EH_MODEL_NAME})
    if(DEFINED EH_MODEL_NAME)
        set(MODEL_NAME "${EH_MODEL_NAME}")
    else()
        set(MODEL_NAME "$ENV{EH_MODEL_NAME}")
    endif()
    target_compile_definitions(${COMPONENT_LIB} PRIVATE EH_MODEL_NAME="${MODEL_NAME}")
endif()
