#pragma once

#include <stddef.h>

/* Format: SH-XXXXXX, where XXXXXX is the last 24 bits of the factory MAC. */
void node_identity_init(void);
const char *node_identity_ble_name(void);
const char *node_identity_device_id(void);

