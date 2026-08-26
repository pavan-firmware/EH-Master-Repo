#include "wifi_manager.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#define TAG "WIFI_MGR"
#else
#define TAG "WIFI_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

static bool s_is_connected = false;
static wifi_connected_cb_t s_on_connected = NULL;
static wifi_disconnected_cb_t s_on_disconnected = NULL;
static char s_current_ssid[33] = {0};

#ifdef ESP_PLATFORM
static esp_netif_t *s_sta_netif = NULL;

static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                               int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        ESP_LOGI(TAG, "Wi-Fi station started, attempting connection to '%s'...", s_current_ssid);
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        s_is_connected = false;
        ESP_LOGW(TAG, "Wi-Fi disconnected, reconnecting...");
        if (s_on_disconnected) {
            s_on_disconnected();
        }
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        char ip_str[16];
        esp_ip4addr_ntoa(&event->ip_info.ip, ip_str, sizeof(ip_str));
        s_is_connected = true;
        ESP_LOGI(TAG, "Wi-Fi connected successfully. Got IP: %s", ip_str);
        if (s_on_connected) {
            s_on_connected(ip_str);
        }
    }
}
#endif

void wifi_manager_init(void)
{
    s_is_connected = false;
#ifdef ESP_PLATFORM
    esp_netif_init();
    esp_event_loop_create_default();
    s_sta_netif = esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);

    esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL, NULL);
    esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL, NULL);
    esp_wifi_set_mode(WIFI_MODE_STA);
#endif
    ESP_LOGI(TAG, "Wi-Fi manager initialized in station mode");
}

bool wifi_manager_set_credentials(const char* ssid, const char* password)
{
    if (!ssid || strlen(ssid) == 0) {
        ESP_LOGE(TAG, "Invalid SSID");
        return false;
    }

    strncpy(s_current_ssid, ssid, sizeof(s_current_ssid) - 1);

#ifdef ESP_PLATFORM
    wifi_config_t wifi_config;
    memset(&wifi_config, 0, sizeof(wifi_config));
    strncpy((char*)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid));
    if (password) {
        strncpy((char*)wifi_config.sta.password, password, sizeof(wifi_config.sta.password));
    }
    wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
#endif

    // Security invariant: NEVER log password!
    ESP_LOGI(TAG, "Credentials set for SSID: %s (password: [PROTECTED])", ssid);
    return true;
}

void wifi_manager_connect(void)
{
#ifdef ESP_PLATFORM
    esp_wifi_start();
#else
    s_is_connected = true;
    if (s_on_connected) {
        s_on_connected("192.168.1.100");
    }
#endif
}

void wifi_manager_disconnect(void)
{
    s_is_connected = false;
#ifdef ESP_PLATFORM
    esp_wifi_disconnect();
    esp_wifi_stop();
#endif
    if (s_on_disconnected) {
        s_on_disconnected();
    }
}

bool wifi_manager_is_connected(void)
{
    return s_is_connected;
}

void wifi_manager_register_callbacks(wifi_connected_cb_t on_connected, wifi_disconnected_cb_t on_disconnected)
{
    s_on_connected = on_connected;
    s_on_disconnected = on_disconnected;
}
