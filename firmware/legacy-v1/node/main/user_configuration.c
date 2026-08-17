#include "user_configuration.h"

#include <string.h>

#include "nvs.h"

#define USER_NAMESPACE "user_cfg"
#define DISPLAY_NAME_KEY "display"
#define ROOM_NAME_KEY "room"
#define BOUND_KEY "bound"

static user_configuration_t s_configuration;

void user_configuration_init(void)
{
    memset(&s_configuration, 0, sizeof(s_configuration));
    nvs_handle_t handle;
    if (nvs_open(USER_NAMESPACE, NVS_READONLY, &handle) != ESP_OK) return;

    size_t display_size = sizeof(s_configuration.display_name);
    size_t room_size = sizeof(s_configuration.room_name);
    uint8_t bound = 0;
    (void)nvs_get_str(handle, DISPLAY_NAME_KEY, s_configuration.display_name, &display_size);
    (void)nvs_get_str(handle, ROOM_NAME_KEY, s_configuration.room_name, &room_size);
    (void)nvs_get_u8(handle, BOUND_KEY, &bound);
    s_configuration.is_bound_to_home = bound != 0;
    nvs_close(handle);
}

const user_configuration_t *user_configuration_get(void)
{
    return &s_configuration;
}
