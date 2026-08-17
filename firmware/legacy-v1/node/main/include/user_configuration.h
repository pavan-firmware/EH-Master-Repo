#pragma once

#include <stdbool.h>

typedef struct {
    bool is_bound_to_home;
    char display_name[33];
    char room_name[33];
} user_configuration_t;

/* Wi-Fi credentials are owned by Espressif secure provisioning, not this module. */
void user_configuration_init(void);
const user_configuration_t *user_configuration_get(void);

