#pragma once

#include <stddef.h>

/* This is read after BLE connection; it is intentionally not advertising data. */
size_t device_info_make_json(char *buffer, size_t buffer_size);

