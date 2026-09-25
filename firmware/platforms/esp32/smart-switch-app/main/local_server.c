#include "local_server.h"
#include <string.h>
#include <stdlib.h>
#include "esp_log.h"
#include "esp_http_server.h"
#include "esp_timer.h"
#include "cJSON.h"
#include "relay_manager.h"
#include "factory_identity_v2.h"
#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char* TAG = "EH_LOCAL_SRV";
static httpd_handle_t s_server = NULL;
static TaskHandle_t s_udp_task = NULL;
static int s_udp_sock = -1;
static volatile bool s_udp_running = false;

static void udp_discovery_task(void *pvParameters)
{
    (void)pvParameters;
    char rx_buffer[256];
    struct sockaddr_in dest_addr;
    dest_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(4210);

    s_udp_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (s_udp_sock < 0) {
        ESP_LOGE(TAG, "Unable to create UDP discovery socket: errno %d", errno);
        s_udp_task = NULL;
        vTaskDelete(NULL);
        return;
    }

    int broadcast = 1;
    setsockopt(s_udp_sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));

    struct timeval tv = { .tv_sec = 1, .tv_usec = 0 };
    setsockopt(s_udp_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    int err = bind(s_udp_sock, (struct sockaddr *)&dest_addr, sizeof(dest_addr));
    if (err < 0) {
        ESP_LOGE(TAG, "UDP discovery socket unable to bind: errno %d", errno);
        close(s_udp_sock);
        s_udp_sock = -1;
        s_udp_task = NULL;
        vTaskDelete(NULL);
        return;
    }

    ESP_LOGI(TAG, "UDP Auto-Discovery Responder listening on port 4210");

    s_udp_running = true;
    while (s_udp_running) {
        struct sockaddr_storage source_addr;
        socklen_t socklen = sizeof(source_addr);
        int len = recvfrom(s_udp_sock, rx_buffer, sizeof(rx_buffer) - 1, 0, (struct sockaddr *)&source_addr, &socklen);

        if (len < 0) {
            continue;
        }

        rx_buffer[len] = '\0';
        if (strstr(rx_buffer, "EH_DISCOVER")) {
            const factory_identity_v2_t* id = factory_identity_v2_get();
            const char* dev_id = id ? id->device_id : "unknown";

            char resp[256];
            snprintf(resp, sizeof(resp),
                     "{\"cmd\":\"EH_DISCOVER_RESP\",\"deviceId\":\"%s\",\"model\":\"EH-SW-3X\",\"port\":80,\"status\":\"ok\"}",
                     dev_id);

            sendto(s_udp_sock, resp, strlen(resp), 0, (struct sockaddr *)&source_addr, sizeof(source_addr));
            ESP_LOGI(TAG, "Responded to UDP discovery request from client for device %s", dev_id);
        }
    }

    if (s_udp_sock >= 0) {
        close(s_udp_sock);
        s_udp_sock = -1;
    }
    s_udp_task = NULL;
    vTaskDelete(NULL);
}

void local_server_broadcast_state(const bool* powers, uint8_t count)
{
    if (s_udp_sock < 0 || !s_udp_running || !powers || count == 0) {
        return;
    }

    const factory_identity_v2_t* id = factory_identity_v2_get();
    const char* dev_id = id ? id->device_id : "unknown";

    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "cmd", "EH_STATE_CHANGED");
    cJSON_AddStringToObject(root, "deviceId", dev_id);
    cJSON* arr = cJSON_CreateArray();
    for (int i = 0; i < count; i++) {
        cJSON* ch = cJSON_CreateObject();
        cJSON_AddNumberToObject(ch, "channelIndex", i + 1);
        cJSON_AddBoolToObject(ch, "power", powers[i]);
        cJSON_AddItemToArray(arr, ch);
    }
    cJSON_AddItemToObject(root, "channels", arr);

    char* str = cJSON_PrintUnformatted(root);
    if (str) {
        struct sockaddr_in bcast_addr;
        memset(&bcast_addr, 0, sizeof(bcast_addr));
        bcast_addr.sin_family = AF_INET;
        bcast_addr.sin_port = htons(4210);
        bcast_addr.sin_addr.s_addr = htonl(INADDR_BROADCAST); // 255.255.255.255

        sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&bcast_addr, sizeof(bcast_addr));
        ESP_LOGI(TAG, "Broadcasted real-time state change over UDP port 4210: %s", str);
        free(str);
    }
    cJSON_Delete(root);
}

static void set_cors_headers(httpd_req_t* req)
{
    httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    httpd_resp_set_hdr(req, "Access-Control-Allow-Headers", "Content-Type, Authorization");
}

/* OPTIONS handler for CORS pre-flight requests */
static esp_err_t options_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_status(req, "204 No Content");
    httpd_resp_send(req, NULL, 0);
    return ESP_OK;
}

/* GET /api/v1/ping - Health check & LAN discovery */
static esp_err_t ping_get_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    const factory_identity_v2_t* id = factory_identity_v2_get();
    const char* dev_id = id ? id->device_id : "unknown";

    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "status", "ok");
    cJSON_AddStringToObject(root, "deviceId", dev_id);
    cJSON_AddStringToObject(root, "model", "EH-SW-3X");
    cJSON_AddBoolToObject(root, "lanMode", true);
    cJSON_AddNumberToObject(root, "uptimeMs", (double)(esp_timer_get_time() / 1000));

    const char* response_str = cJSON_PrintUnformatted(root);
    httpd_resp_sendstr(req, response_str);

    free((void*)response_str);
    cJSON_Delete(root);
    return ESP_OK;
}

/* GET /api/v1/state - Query live relay states */
static esp_err_t state_get_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    const factory_identity_v2_t* id = factory_identity_v2_get();
    const char* dev_id = id ? id->device_id : "unknown";

    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "deviceId", dev_id);
    cJSON_AddBoolToObject(root, "online", true);

    cJSON* channels = cJSON_AddArrayToObject(root, "channels");
    for (int i = 1; i <= EH_RELAY_CHANNEL_COUNT; i++) {
        cJSON* ch = cJSON_CreateObject();
        cJSON_AddNumberToObject(ch, "channelIndex", i);
        cJSON_AddBoolToObject(ch, "power", relay_manager_get_power((uint8_t)i));
        cJSON_AddItemToArray(channels, ch);
    }

    const char* response_str = cJSON_PrintUnformatted(root);
    httpd_resp_sendstr(req, response_str);

    free((void*)response_str);
    cJSON_Delete(root);
    return ESP_OK;
}

/* POST /api/v1/control - Direct local LAN relay actuation */
static esp_err_t control_post_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    int total_len = req->content_len;
    if (total_len <= 0 || total_len > 255) {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid content length");
        return ESP_FAIL;
    }

    char buf[256];
    int cur_len = 0;
    int received = 0;
    while (cur_len < total_len) {
        received = httpd_req_recv(req, buf + cur_len, total_len - cur_len);
        if (received <= 0) {
            if (received == HTTPD_SOCK_ERR_TIMEOUT) {
                httpd_resp_send_408(req);
            }
            return ESP_FAIL;
        }
        cur_len += received;
    }
    buf[total_len] = '\0';

    cJSON* root = cJSON_Parse(buf);
    if (!root) {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON payload");
        return ESP_FAIL;
    }

    cJSON* ch_item = cJSON_GetObjectItem(root, "channel");
    if (!ch_item) ch_item = cJSON_GetObjectItem(root, "channelIndex");

    cJSON* pwr_item = cJSON_GetObjectItem(root, "power");
    if (!pwr_item) pwr_item = cJSON_GetObjectItem(root, "value");
    if (!pwr_item) pwr_item = cJSON_GetObjectItem(root, "enabled");

    if (!ch_item || !cJSON_IsNumber(ch_item) || !pwr_item || !cJSON_IsBool(pwr_item)) {
        cJSON_Delete(root);
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing channel or power parameters");
        return ESP_FAIL;
    }

    uint8_t channel = (uint8_t)ch_item->valueint;
    bool power = cJSON_IsTrue(pwr_item);

    ESP_LOGI(TAG, "LOCAL_LAN_COMMAND_RECEIVED channel=%d power=%s", channel, power ? "ON" : "OFF");

    bool success = relay_manager_set_power(channel, power, "LOCAL_HTTP");

    cJSON* resp = cJSON_CreateObject();
    cJSON_AddBoolToObject(resp, "success", success);
    cJSON_AddNumberToObject(resp, "channel", channel);
    cJSON_AddBoolToObject(resp, "power", relay_manager_get_power(channel));
    cJSON_AddStringToObject(resp, "mode", "LOCAL_LAN");

    const char* response_str = cJSON_PrintUnformatted(resp);
    httpd_resp_sendstr(req, response_str);

    free((void*)response_str);
    cJSON_Delete(resp);
    cJSON_Delete(root);
    return ESP_OK;
}

bool local_server_start(void)
{
    if (s_server != NULL) {
        ESP_LOGI(TAG, "Local HTTP server already running");
        return true;
    }

    httpd_config_t config = HTTPD_DEFAULT_CONFIG();
    config.server_port = 80;
    config.ctrl_port = 32768;
    config.max_open_sockets = 4;
    config.stack_size = 8192; // 8KB stack prevents FreeRTOS stack overflow on JSON/NVS operations
    config.lru_purge_enable = true;

    ESP_LOGI(TAG, "Starting Local LAN HTTP Server on port %d (stack=%d)...", config.server_port, config.stack_size);
    if (httpd_start(&s_server, &config) != ESP_OK) {
        ESP_LOGE(TAG, "Failed to start Local LAN HTTP Server");
        return false;
    }

    // Register URI Handlers
    httpd_uri_t ping_uri = {
        .uri       = "/api/v1/ping",
        .method    = HTTP_GET,
        .handler   = ping_get_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &ping_uri);

    httpd_uri_t state_uri = {
        .uri       = "/api/v1/state",
        .method    = HTTP_GET,
        .handler   = state_get_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &state_uri);

    httpd_uri_t control_uri = {
        .uri       = "/api/v1/control",
        .method    = HTTP_POST,
        .handler   = control_post_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &control_uri);

    httpd_uri_t options_control_uri = {
        .uri       = "/api/v1/control",
        .method    = HTTP_OPTIONS,
        .handler   = options_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &options_control_uri);

    httpd_uri_t options_state_uri = {
        .uri       = "/api/v1/state",
        .method    = HTTP_OPTIONS,
        .handler   = options_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &options_state_uri);

    // Start UDP auto-discovery responder task
    if (s_udp_task == NULL) {
        xTaskCreate(udp_discovery_task, "eh_udp_disc", 4096, NULL, 5, &s_udp_task);
    }

    ESP_LOGI(TAG, "Local LAN HTTP Server started successfully on port 80");
    return true;
}

void local_server_stop(void)
{
    if (s_udp_running) {
        s_udp_running = false;
        if (s_udp_sock >= 0) {
            // Shutdown socket to unblock recvfrom immediately
            shutdown(s_udp_sock, 0);
            close(s_udp_sock);
            s_udp_sock = -1;
        }
    }
    if (s_server) {
        ESP_LOGI(TAG, "Stopping Local LAN HTTP Server...");
        httpd_stop(s_server);
        s_server = NULL;
    }
}

bool local_server_is_running(void)
{
    return s_server != NULL;
}
