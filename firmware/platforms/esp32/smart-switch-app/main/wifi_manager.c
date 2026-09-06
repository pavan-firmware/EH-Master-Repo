#include "wifi_manager.h"
#include <stdio.h>
#include <string.h>

#ifdef ESP_PLATFORM
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "nvs_flash.h"
#include "nvs.h"
#define TAG "WIFI_MGR"
#else
#define TAG "WIFI_MGR"
#define ESP_LOGI(tag, fmt, ...) printf("[%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGW(tag, fmt, ...) printf("[WARN:%s] " fmt "\n", tag, ##__VA_ARGS__)
#define ESP_LOGE(tag, fmt, ...) printf("[ERR:%s] " fmt "\n", tag, ##__VA_ARGS__)
#endif

#define WIFI_NVS_NAMESPACE "wifi_creds"
#define KEY_WIFI_SSID      "wifi_ssid"
#define KEY_WIFI_PASS      "wifi_pass"

static bool s_is_connected = false;
static bool s_has_credentials = false;
static wifi_connected_cb_t s_on_connected = NULL;
static wifi_disconnected_cb_t s_on_disconnected = NULL;
static char s_current_ssid[33] = {0};
static char s_current_password[65] = {0};

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
    s_has_credentials = false;
    memset(s_current_ssid, 0, sizeof(s_current_ssid));
    memset(s_current_password, 0, sizeof(s_current_password));

#ifdef ESP_PLATFORM
    esp_netif_init();
    esp_event_loop_create_default();
    s_sta_netif = esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);

    esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL, NULL);
    esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL, NULL);
    esp_wifi_set_mode(WIFI_MODE_STA);

    // Read stored credentials from NVS
    nvs_handle_t handle;
    if (nvs_open(WIFI_NVS_NAMESPACE, NVS_READONLY, &handle) == ESP_OK) {
        size_t ssid_len = sizeof(s_current_ssid);
        size_t pass_len = sizeof(s_current_password);
        if (nvs_get_str(handle, KEY_WIFI_SSID, s_current_ssid, &ssid_len) == ESP_OK && strlen(s_current_ssid) > 0) {
            nvs_get_str(handle, KEY_WIFI_PASS, s_current_password, &pass_len);
            s_has_credentials = true;

            wifi_config_t wifi_config;
            memset(&wifi_config, 0, sizeof(wifi_config));
            strncpy((char*)wifi_config.sta.ssid, s_current_ssid, sizeof(wifi_config.sta.ssid) - 1);
            strncpy((char*)wifi_config.sta.password, s_current_password, sizeof(wifi_config.sta.password) - 1);
            wifi_config.sta.threshold.authmode = (strlen(s_current_password) > 0) ? WIFI_AUTH_WPA2_PSK : WIFI_AUTH_OPEN;
            esp_wifi_set_config(WIFI_IF_STA, &wifi_config);

            ESP_LOGI(TAG, "Loaded stored Wi-Fi credentials from NVS for SSID: %s", s_current_ssid);
        }
        nvs_close(handle);
    }
#endif
    ESP_LOGI(TAG, "Wi-Fi manager initialized in station mode (has_credentials: %s)", s_has_credentials ? "true" : "false");
}

bool wifi_manager_has_credentials(void)
{
    return s_has_credentials && (strlen(s_current_ssid) > 0);
}

bool wifi_manager_set_credentials(const char* ssid, const char* password)
{
    if (!ssid || strlen(ssid) == 0 || strlen(ssid) >= sizeof(s_current_ssid)) {
        ESP_LOGE(TAG, "Invalid SSID");
        return false;
    }

    strncpy(s_current_ssid, ssid, sizeof(s_current_ssid) - 1);
    s_current_ssid[sizeof(s_current_ssid) - 1] = '\0';

    if (password) {
        strncpy(s_current_password, password, sizeof(s_current_password) - 1);
        s_current_password[sizeof(s_current_password) - 1] = '\0';
    } else {
        memset(s_current_password, 0, sizeof(s_current_password));
    }
    s_has_credentials = true;

#ifdef ESP_PLATFORM
    // 1. Persist to NVS
    nvs_handle_t handle;
    if (nvs_open(WIFI_NVS_NAMESPACE, NVS_READWRITE, &handle) == ESP_OK) {
        nvs_set_str(handle, KEY_WIFI_SSID, s_current_ssid);
        nvs_set_str(handle, KEY_WIFI_PASS, s_current_password);
        nvs_commit(handle);
        nvs_close(handle);
        ESP_LOGI(TAG, "Persisted Wi-Fi credentials to NVS");
    } else {
        ESP_LOGE(TAG, "Failed to open NVS namespace %s for writing", WIFI_NVS_NAMESPACE);
    }

    // 2. Configure driver
    wifi_config_t wifi_config;
    memset(&wifi_config, 0, sizeof(wifi_config));
    strncpy((char*)wifi_config.sta.ssid, s_current_ssid, sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char*)wifi_config.sta.password, s_current_password, sizeof(wifi_config.sta.password) - 1);
    wifi_config.sta.threshold.authmode = (strlen(s_current_password) > 0) ? WIFI_AUTH_WPA2_PSK : WIFI_AUTH_OPEN;

    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
#endif

    // Security invariant: NEVER log password!
    ESP_LOGI(TAG, "Credentials set for SSID: %s (password: [PROTECTED])", s_current_ssid);
    return true;
}

bool wifi_manager_get_credentials(char* out_ssid, size_t ssid_len, char* out_password, size_t pass_len)
{
    if (!s_has_credentials) {
        return false;
    }
    if (out_ssid && ssid_len > 0) {
        strncpy(out_ssid, s_current_ssid, ssid_len - 1);
        out_ssid[ssid_len - 1] = '\0';
    }
    if (out_password && pass_len > 0) {
        strncpy(out_password, s_current_password, pass_len - 1);
        out_password[pass_len - 1] = '\0';
    }
    return true;
}

bool wifi_manager_clear_credentials(void)
{
    s_has_credentials = false;
    memset(s_current_ssid, 0, sizeof(s_current_ssid));
    memset(s_current_password, 0, sizeof(s_current_password));

#ifdef ESP_PLATFORM
    nvs_handle_t handle;
    if (nvs_open(WIFI_NVS_NAMESPACE, NVS_READWRITE, &handle) == ESP_OK) {
        nvs_erase_all(handle);
        nvs_commit(handle);
        nvs_close(handle);
    }
#endif
    ESP_LOGI(TAG, "Wi-Fi credentials cleared from storage");
    return true;
}

void wifi_manager_connect(void)
{
    if (!wifi_manager_has_credentials()) {
        ESP_LOGE(TAG, "Cannot connect: No credentials configured");
        return;
    }
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
