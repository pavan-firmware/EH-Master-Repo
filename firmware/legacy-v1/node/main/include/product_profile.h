#pragma once

#include <stdint.h>
#include <stddef.h>

typedef struct {
    const char *brand;
    const char *product_name;
    const char *model;
    const char *hardware_revision;
    const char *firmware_version;
    uint32_t capability_mask;
} product_profile_t;

enum {
    PRODUCT_CAP_TEMPERATURE_HUMIDITY = 1U << 0,
    PRODUCT_CAP_SOIL_MOISTURE = 1U << 1,
    PRODUCT_CAP_AMBIENT_LIGHT = 1U << 2,
    PRODUCT_CAP_MIST_MAKER = 1U << 3,
};

const product_profile_t *product_profile_get(void);

/* Non-sensitive information safe to read before authenticated commissioning. */
size_t product_profile_make_public_json(char *buffer, size_t buffer_size);
