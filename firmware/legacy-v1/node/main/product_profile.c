#include "product_profile.h"

#include <stdio.h>

static const product_profile_t s_profile = {
    .brand = "Smart Home",
    .product_name = "Smart Home Room Node",
    .model = "SH-NODE-1",
    .hardware_revision = "1.0",
    .firmware_version = "0.1.0-dev",
    .capability_mask = PRODUCT_CAP_TEMPERATURE_HUMIDITY |
                       PRODUCT_CAP_SOIL_MOISTURE |
                       PRODUCT_CAP_AMBIENT_LIGHT |
                       PRODUCT_CAP_MIST_MAKER,
};

const product_profile_t *product_profile_get(void)
{
    return &s_profile;
}

size_t product_profile_make_public_json(char *buffer, size_t buffer_size)
{
    /* Keep unauthenticated discovery data within the default 20-byte ATT
       payload. Full product metadata belongs to the authenticated path. */
    int length = snprintf(buffer, buffer_size, "{\"p\":\"Node\"}");
    return length > 0 && (size_t)length < buffer_size ? (size_t)length : 0;
}
