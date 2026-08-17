#pragma once

#include <stdbool.h>

/* Development units create this once. Production units overwrite it in factory provisioning. */
void factory_identity_init(void);
const char *factory_identity_device_id(void);
const char *factory_identity_serial_number(void);
bool factory_identity_is_development(void);

