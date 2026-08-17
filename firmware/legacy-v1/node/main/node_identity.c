#include "node_identity.h"

#include <stdio.h>

#include "esp_err.h"
#include "esp_mac.h"

static char s_ble_name[10];
static char s_device_id[16];

void node_identity_init(void)
{
    uint8_t mac[6] = {0};
    ESP_ERROR_CHECK(esp_read_mac(mac, ESP_MAC_WIFI_STA));
    snprintf(s_ble_name, sizeof(s_ble_name), "SH-%02X%02X%02X", mac[3], mac[4], mac[5]);
    snprintf(s_device_id, sizeof(s_device_id), "node-%02X%02X%02X", mac[3], mac[4], mac[5]);
}

const char *node_identity_ble_name(void)
{
    return s_ble_name;
}

const char *node_identity_device_id(void)
{
    return s_device_id;
}
