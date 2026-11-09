#include "local_server.h"
#include "board_config.h"
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
#include "reset_button.h"
#include "edge_routine_engine.h"
#include "time_sync_manager.h"

static void inspect_and_inject_client_time(httpd_req_t* req, cJSON* body) {
    if (req) {
        char epoch_hdr[32];
        if (httpd_req_get_hdr_value_str(req, "X-Client-Epoch-Sec", epoch_hdr, sizeof(epoch_hdr)) == ESP_OK) {
            uint64_t sec = strtoull(epoch_hdr, NULL, 10);
            if (sec >= MIN_VALID_EPOCH) {
                time_sync_manager_inject_epoch(sec, "LOCAL_HTTP_HEADER");
            }
        }
    }
    if (body) {
        cJSON* ut = cJSON_GetObjectItem(body, "unix_time");
        if (!ut) ut = cJSON_GetObjectItem(body, "epoch");
        if (ut && cJSON_IsNumber(ut) && ut->valuedouble >= MIN_VALID_EPOCH) {
            time_sync_manager_inject_epoch((uint64_t)ut->valuedouble, "LOCAL_HTTP_BODY");
        }
    }
}

static const char* TAG = "EH_LOCAL_SRV";
static httpd_handle_t s_server = NULL;
static TaskHandle_t s_udp_task = NULL;
static int s_udp_sock = -1;
static volatile bool s_udp_running = false;
static struct sockaddr_in s_last_client_addr;
static volatile bool s_has_client_addr = false;

static const char *get_local_model_name(void)
{
    static char s_model[32] = {0};
    if (s_model[0] != '\0') return s_model;
    const char *v = factory_identity_v2_get_variant();
    if (!v || !v[0]) {
        v = EH_PRODUCT_VARIANT;
    }
    const char *pt = factory_identity_v2_get_product_type();
    bool is_sk = (pt && (strstr(pt, "SOCKET") != NULL || strstr(pt, "socket") != NULL));
    bool is_em = (EH_FEATURE_ENERGY_MONITORING != 0);
    snprintf(s_model, sizeof(s_model), "%s-%s%s", is_sk ? "EH-SK" : "EH-SW", v, is_em ? "-EM" : "");
    return s_model;
}
#ifdef EH_MODEL_NAME
#undef EH_MODEL_NAME
#endif
#define EH_MODEL_NAME get_local_model_name()

#ifndef EH_FEATURE_ENERGY_MONITORING
#define EH_FEATURE_ENERGY_MONITORING 0
#endif

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

        if (source_addr.ss_family == AF_INET) {
            memcpy(&s_last_client_addr, &source_addr, sizeof(struct sockaddr_in));
            s_has_client_addr = true;
        }

        rx_buffer[len] = '\0';

        // Passive time injection from discovery payload
        if (strstr(rx_buffer, "unix_time") || strstr(rx_buffer, "epoch")) {
            cJSON* ut_json = cJSON_Parse(rx_buffer);
            if (ut_json) {
                cJSON* ut_item = cJSON_GetObjectItem(ut_json, "unix_time");
                if (!ut_item) ut_item = cJSON_GetObjectItem(ut_json, "epoch");
                if (ut_item && cJSON_IsNumber(ut_item) && ut_item->valuedouble >= MIN_VALID_EPOCH) {
                    time_sync_manager_inject_epoch((uint64_t)ut_item->valuedouble, "UDP_DISCOVERY");
                }
                cJSON_Delete(ut_json);
            }
        }

        if (strstr(rx_buffer, "EH_DISCOVER")) {
            const factory_identity_v2_t* id = factory_identity_v2_get();
            const char* dev_id = id ? id->device_id : "unknown";

            char resp[256];
            snprintf(resp, sizeof(resp),
                     "{\"cmd\":\"EH_DISCOVER_RESP\",\"deviceId\":\"%s\",\"model\":\"%s\",\"channelCount\":%d,\"hasEnergyMetering\":%s,\"port\":80,\"status\":\"ok\"}",
                     dev_id, EH_MODEL_NAME, (int)EH_RELAY_CHANNEL_COUNT,
                     (EH_FEATURE_ENERGY_MONITORING != 0) ? "true" : "false");

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
    cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
    cJSON_AddNumberToObject(root, "channelCount", (int)EH_RELAY_CHANNEL_COUNT);
    cJSON_AddBoolToObject(root, "hasEnergyMetering", (EH_FEATURE_ENERGY_MONITORING != 0));
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

        // Dual transmission: general subnet broadcast + direct unicast to connected phone
        sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&bcast_addr, sizeof(bcast_addr));
        if (s_has_client_addr) {
            struct sockaddr_in client_dest;
            memcpy(&client_dest, &s_last_client_addr, sizeof(client_dest));
            client_dest.sin_port = htons(4210);
            sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&client_dest, sizeof(client_dest));
        }

        ESP_LOGI(TAG, "Broadcasted real-time state change over UDP port 4210 (instant sync): %s", str);
        free(str);
    }
    cJSON_Delete(root);
}

void local_server_broadcast_boot_announce(const bool* powers, uint8_t count)
{
    if (s_udp_sock < 0 || !s_udp_running) {
        return;
    }

    const factory_identity_v2_t* id = factory_identity_v2_get();
    const char* dev_id = id ? id->device_id : "unknown";

    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "cmd", "EH_BOOT_ANNOUNCE");
    cJSON_AddStringToObject(root, "deviceId", dev_id);
    cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
    cJSON_AddNumberToObject(root, "channelCount", (int)EH_RELAY_CHANNEL_COUNT);
    cJSON_AddBoolToObject(root, "hasEnergyMetering", (EH_FEATURE_ENERGY_MONITORING != 0));
    cJSON_AddNumberToObject(root, "port", 80);
    cJSON_AddStringToObject(root, "status", "ok");

    if (powers && count > 0) {
        cJSON* arr = cJSON_CreateArray();
        for (int i = 0; i < count; i++) {
            cJSON* ch = cJSON_CreateObject();
            cJSON_AddNumberToObject(ch, "channelIndex", i + 1);
            cJSON_AddBoolToObject(ch, "power", powers[i]);
            cJSON_AddItemToArray(arr, ch);
        }
        cJSON_AddItemToObject(root, "channels", arr);
    }

    char* str = cJSON_PrintUnformatted(root);
    if (str) {
        struct sockaddr_in bcast_addr;
        memset(&bcast_addr, 0, sizeof(bcast_addr));
        bcast_addr.sin_family = AF_INET;
        bcast_addr.sin_port = htons(4210);
        bcast_addr.sin_addr.s_addr = htonl(INADDR_BROADCAST); // 255.255.255.255

        // Broadcast to general subnet
        sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&bcast_addr, sizeof(bcast_addr));
        if (s_has_client_addr) {
            struct sockaddr_in client_dest;
            memcpy(&client_dest, &s_last_client_addr, sizeof(client_dest));
            client_dest.sin_port = htons(4210);
            sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&client_dest, sizeof(client_dest));
        }

        ESP_LOGI(TAG, "Broadcasted boot announcement over UDP port 4210: %s", str);
        free(str);
    }
    cJSON_Delete(root);
}

#ifdef ESP_PLATFORM
typedef struct {
    bool powers[EH_RELAY_CHANNEL_COUNT];
    uint8_t count;
} boot_announce_burst_ctx_t;

static void boot_announce_burst_task(void* arg)
{
    boot_announce_burst_ctx_t* ctx = (boot_announce_burst_ctx_t*)arg;
    for (int i = 0; i < 3; i++) {
        local_server_broadcast_boot_announce(ctx->powers, ctx->count);
        if (i < 2) {
            vTaskDelay(pdMS_TO_TICKS(1500));
        }
    }
    free(ctx);
    vTaskDelete(NULL);
}

void local_server_start_boot_announce_burst(const bool* powers, uint8_t count)
{
    boot_announce_burst_ctx_t* ctx = (boot_announce_burst_ctx_t*)calloc(1, sizeof(boot_announce_burst_ctx_t));
    if (ctx) {
        if (powers && count > 0) {
            uint8_t copy_count = (count <= EH_RELAY_CHANNEL_COUNT) ? count : EH_RELAY_CHANNEL_COUNT;
            memcpy(ctx->powers, powers, copy_count * sizeof(bool));
            ctx->count = copy_count;
        }
        if (xTaskCreate(boot_announce_burst_task, "boot_ann_burst", 4096, ctx, 5, NULL) != pdPASS) {
            local_server_broadcast_boot_announce(powers, count);
            free(ctx);
        }
    } else {
        local_server_broadcast_boot_announce(powers, count);
    }
}
#else
void local_server_start_boot_announce_burst(const bool* powers, uint8_t count)
{
    for (int i = 0; i < 3; i++) {
        local_server_broadcast_boot_announce(powers, count);
    }
}
#endif

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
    cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
    cJSON_AddNumberToObject(root, "channelCount", EH_RELAY_CHANNEL_COUNT);
    cJSON_AddBoolToObject(root, "hasEnergyMetering", (EH_FEATURE_ENERGY_MONITORING != 0));
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

    inspect_and_inject_client_time(req, NULL);

    cJSON* root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "deviceId", dev_id);
    cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
    cJSON_AddNumberToObject(root, "channelCount", EH_RELAY_CHANNEL_COUNT);
    cJSON_AddBoolToObject(root, "hasEnergyMetering", (EH_FEATURE_ENERGY_MONITORING != 0));
    cJSON_AddBoolToObject(root, "online", true);
    cJSON_AddBoolToObject(root, "timeSynced", time_sync_manager_is_synced());
    cJSON_AddNumberToObject(root, "epoch", (double)time(NULL));

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

#ifdef ESP_PLATFORM
    int sockfd = httpd_req_to_sockfd(req);
    if (sockfd >= 0) {
        struct sockaddr_in peer;
        socklen_t peer_len = sizeof(peer);
        if (getpeername(sockfd, (struct sockaddr*)&peer, &peer_len) == 0 && peer.sin_family == AF_INET) {
            memcpy(&s_last_client_addr, &peer, sizeof(struct sockaddr_in));
            s_has_client_addr = true;
        }
    }
#endif

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

    inspect_and_inject_client_time(req, root);

    cJSON* ch_item = cJSON_GetObjectItem(root, "channel");
    if (!ch_item) ch_item = cJSON_GetObjectItem(root, "channelIndex");

    cJSON* pwr_item = cJSON_GetObjectItem(root, "power");
    if (!pwr_item) pwr_item = cJSON_GetObjectItem(root, "value");
    if (!pwr_item) pwr_item = cJSON_GetObjectItem(root, "enabled");

    cJSON* toggle_item = cJSON_GetObjectItem(root, "toggle");
    cJSON* action_item = cJSON_GetObjectItem(root, "action");
    bool is_toggle = false;
    if (toggle_item && (cJSON_IsTrue(toggle_item) || (cJSON_IsString(toggle_item) && strcmp(toggle_item->valuestring, "toggle") == 0))) {
        is_toggle = true;
    }
    if (action_item && cJSON_IsString(action_item) && strcmp(action_item->valuestring, "toggle") == 0) {
        is_toggle = true;
    }

    if (!ch_item || !cJSON_IsNumber(ch_item) || (!is_toggle && (!pwr_item || !cJSON_IsBool(pwr_item)))) {
        cJSON_Delete(root);
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing channel or power parameters");
        return ESP_FAIL;
    }

    uint8_t channel = (uint8_t)ch_item->valueint;
    bool success = false;
    if (is_toggle) {
        ESP_LOGI(TAG, "LOCAL_LAN_COMMAND_RECEIVED channel=%d action=TOGGLE", channel);
        success = relay_manager_toggle_power(channel, "LOCAL_HTTP");
    } else {
        bool power = cJSON_IsTrue(pwr_item);
        ESP_LOGI(TAG, "LOCAL_LAN_COMMAND_RECEIVED channel=%d power=%s", channel, power ? "ON" : "OFF");
        if (!power) {
            // Dual Emergency Stop: Turning off channel immediately disarms edge routine timer on that channel
            edge_routine_engine_emergency_stop(channel, "LOCAL_HTTP_OFF");
        }
        success = relay_manager_set_power(channel, power, "LOCAL_HTTP");
    }

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

/* POST /api/v1/reset - Remote Factory Reset & Wipe Wi-Fi Credentials */
static esp_err_t reset_post_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    cJSON* resp = cJSON_CreateObject();
    cJSON_AddBoolToObject(resp, "success", true);
    cJSON_AddStringToObject(resp, "message", "Factory reset initiated. Device entering BLE provisioning.");

    const char* response_str = cJSON_PrintUnformatted(resp);
    httpd_resp_sendstr(req, response_str);

    free((void*)response_str);
    cJSON_Delete(resp);

    ESP_LOGW(TAG, "REMOTE_FACTORY_RESET_TRIGGERED: Erasing Wi-Fi credentials, edge routines, and resetting device...");
    edge_routine_engine_clear_all();
    reset_button_trigger_factory_reset();
    return ESP_OK;
}

/* GET /api/v1/routines - Query configured and active edge routines */
static esp_err_t routines_get_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    inspect_and_inject_client_time(req, NULL);

    char* response_str = edge_routine_engine_to_json_string();
    if (!response_str) {
        httpd_resp_sendstr(req, "[]");
    } else {
        httpd_resp_sendstr(req, response_str);
        free(response_str);
    }
    return ESP_OK;
}

/* POST /api/v1/routines - Create or update edge routine (wear-leveled NVS persistence) */
static esp_err_t routines_post_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    int total_len = req->content_len;
    if (total_len <= 0 || total_len > 512) {
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid content length");
        return ESP_FAIL;
    }

    char buf[513];
    int cur_len = 0;
    while (cur_len < total_len) {
        int received = httpd_req_recv(req, buf + cur_len, total_len - cur_len);
        if (received <= 0) {
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

    inspect_and_inject_client_time(req, root);

    cJSON* id_item = cJSON_GetObjectItem(root, "id");
    cJSON* name_item = cJSON_GetObjectItem(root, "name");
    cJSON* ch_item = cJSON_GetObjectItem(root, "channel");
    if (!ch_item) ch_item = cJSON_GetObjectItem(root, "channelIndex");
    cJSON* pwr_item = cJSON_GetObjectItem(root, "power");
    if (!pwr_item) pwr_item = cJSON_GetObjectItem(root, "targetPower");
    cJSON* toggle_item = cJSON_GetObjectItem(root, "isToggle");
    if (!toggle_item) toggle_item = cJSON_GetObjectItem(root, "toggle");
    cJSON* trig_item = cJSON_GetObjectItem(root, "triggerType");
    cJSON* dur_item = cJSON_GetObjectItem(root, "durationSec");
    if (!dur_item) dur_item = cJSON_GetObjectItem(root, "duration");
    if (!dur_item) dur_item = cJSON_GetObjectItem(root, "pulseDurationSeconds");
    if (!dur_item) dur_item = cJSON_GetObjectItem(root, "pulseSec");
    cJSON* en_item = cJSON_GetObjectItem(root, "enabled");

    if (!id_item || !cJSON_IsString(id_item) || !ch_item || !cJSON_IsNumber(ch_item)) {
        cJSON_Delete(root);
        httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing required id or channel");
        return ESP_FAIL;
    }

    edge_routine_t r;
    memset(&r, 0, sizeof(r));
    strncpy(r.id, id_item->valuestring, sizeof(r.id) - 1);
    if (name_item && cJSON_IsString(name_item)) {
        strncpy(r.name, name_item->valuestring, sizeof(r.name) - 1);
    } else {
        snprintf(r.name, sizeof(r.name), "Routine %.30s", r.id);
    }
    r.channel_index = (uint8_t)ch_item->valueint;
    r.target_power = pwr_item ? cJSON_IsTrue(pwr_item) : true;
    r.is_toggle = toggle_item ? cJSON_IsTrue(toggle_item) : false;
    r.duration_sec = dur_item ? (uint32_t)dur_item->valueint : 0;
    r.enabled = en_item ? cJSON_IsTrue(en_item) : true;

    cJSON* hr_item = cJSON_GetObjectItem(root, "hour");
    cJSON* min_item = cJSON_GetObjectItem(root, "minute");
    cJSON* days_item = cJSON_GetObjectItem(root, "daysMask");
    if (!days_item) days_item = cJSON_GetObjectItem(root, "days");

    if (hr_item && cJSON_IsNumber(hr_item)) r.hour = (uint8_t)hr_item->valueint;
    if (min_item && cJSON_IsNumber(min_item)) r.minute = (uint8_t)min_item->valueint;
    if (days_item && cJSON_IsNumber(days_item) && days_item->valueint > 0) {
        r.days_mask = (uint8_t)days_item->valueint;
    } else {
        r.days_mask = 0x7F;
    }

    if (trig_item && cJSON_IsNumber(trig_item)) {
        r.trigger_type = (edge_trigger_type_t)trig_item->valueint;
    } else if (hr_item || min_item) {
        r.trigger_type = EDGE_TRIGGER_SCHEDULE;
    } else if (r.duration_sec > 0) {
        r.trigger_type = EDGE_TRIGGER_TIMER;
    } else {
        r.trigger_type = EDGE_TRIGGER_SCHEDULE;
    }

    cJSON_Delete(root);

    bool success = edge_routine_engine_upsert_routine(&r);

    cJSON* resp = cJSON_CreateObject();
    cJSON_AddBoolToObject(resp, "success", success);
    cJSON_AddStringToObject(resp, "id", r.id);
    const char* resp_str = cJSON_PrintUnformatted(resp);
    httpd_resp_sendstr(req, resp_str);
    free((void*)resp_str);
    cJSON_Delete(resp);
    return ESP_OK;
}

/* DELETE /api/v1/routines - Delete edge routine by ID (via query parameter or JSON body) */
static esp_err_t routines_delete_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    char routine_id[ROUTINE_ID_MAX_LEN] = {0};

    // 1. Try URL query parameter (?id=xxx)
    char q_buf[128];
    if (httpd_req_get_url_query_str(req, q_buf, sizeof(q_buf)) == ESP_OK) {
        httpd_query_key_value(q_buf, "id", routine_id, sizeof(routine_id));
    }

    // 2. Try JSON body if query didn't provide id
    if (routine_id[0] == '\0' && req->content_len > 0 && req->content_len <= 128) {
        char buf[129];
        int ret = httpd_req_recv(req, buf, req->content_len);
        if (ret > 0) {
            buf[ret] = '\0';
            cJSON* root = cJSON_Parse(buf);
            if (root) {
                cJSON* id_item = cJSON_GetObjectItem(root, "id");
                if (id_item && cJSON_IsString(id_item)) {
                    strncpy(routine_id, id_item->valuestring, sizeof(routine_id) - 1);
                }
                cJSON_Delete(root);
            }
        }
    }

    bool success = false;
    if (strcmp(routine_id, "all") == 0) {
        edge_routine_engine_clear_all();
        success = true;
        ESP_LOGI(TAG, "LOCAL_HTTP: ALL edge routines cleared from chip");
    } else if (routine_id[0] != '\0') {
        success = edge_routine_engine_delete_routine(routine_id);
        ESP_LOGI(TAG, "LOCAL_HTTP: Routine '%s' deleted from edge engine (success=%d)", routine_id, success);
    } else {
        ESP_LOGW(TAG, "LOCAL_HTTP: Delete routine failed, missing 'id' parameter");
    }

    cJSON* resp = cJSON_CreateObject();
    cJSON_AddBoolToObject(resp, "success", success);
    cJSON_AddStringToObject(resp, "id", routine_id);
    const char* resp_str = cJSON_PrintUnformatted(resp);
    httpd_resp_sendstr(req, resp_str);
    free((void*)resp_str);
    cJSON_Delete(resp);
    return ESP_OK;
}

/* POST /api/v1/routines/stop - Dual Emergency Stop (Local LAN) */
static esp_err_t routines_stop_post_handler(httpd_req_t* req)
{
    set_cors_headers(req);
    httpd_resp_set_type(req, "application/json");

    uint8_t channel = 0; // 0 = all channels by default
    if (req->content_len > 0 && req->content_len <= 128) {
        char buf[129];
        int ret = httpd_req_recv(req, buf, req->content_len);
        if (ret > 0) {
            buf[ret] = '\0';
            cJSON* root = cJSON_Parse(buf);
            if (root) {
                cJSON* ch_item = cJSON_GetObjectItem(root, "channel");
                if (!ch_item) ch_item = cJSON_GetObjectItem(root, "channelIndex");
                if (ch_item && cJSON_IsNumber(ch_item)) {
                    channel = (uint8_t)ch_item->valueint;
                }
                cJSON_Delete(root);
            }
        }
    }

    ESP_LOGW(TAG, "LOCAL_LAN_EMERGENCY_STOP executed for channel %d", channel);
    edge_routine_engine_emergency_stop(channel, "LOCAL_HTTP_STOP");

    cJSON* resp = cJSON_CreateObject();
    cJSON_AddBoolToObject(resp, "success", true);
    cJSON_AddNumberToObject(resp, "channel", channel);
    cJSON_AddStringToObject(resp, "message", "Emergency stop executed");
    const char* resp_str = cJSON_PrintUnformatted(resp);
    httpd_resp_sendstr(req, resp_str);
    free((void*)resp_str);
    cJSON_Delete(resp);
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
    config.max_open_sockets = 7;
    config.max_uri_handlers = 16;
    config.recv_wait_timeout = 3;
    config.send_wait_timeout = 3;
    config.stack_size = 8192; // 8KB stack prevents FreeRTOS stack overflow on JSON/NVS operations
    config.lru_purge_enable = true;

    ESP_LOGI(TAG, "Starting Local LAN HTTP Server on port %d (stack=%d, max_sockets=%d)...", config.server_port, config.stack_size, config.max_open_sockets);
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

    httpd_uri_t reset_uri = {
        .uri       = "/api/v1/reset",
        .method    = HTTP_POST,
        .handler   = reset_post_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &reset_uri);

    httpd_uri_t options_reset_uri = {
        .uri       = "/api/v1/reset",
        .method    = HTTP_OPTIONS,
        .handler   = options_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &options_reset_uri);

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

    /* Edge Routine Engine Endpoints */
    httpd_uri_t routines_get_uri = {
        .uri       = "/api/v1/routines",
        .method    = HTTP_GET,
        .handler   = routines_get_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &routines_get_uri);

    httpd_uri_t routines_post_uri = {
        .uri       = "/api/v1/routines",
        .method    = HTTP_POST,
        .handler   = routines_post_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &routines_post_uri);

    httpd_uri_t routines_delete_uri = {
        .uri       = "/api/v1/routines",
        .method    = HTTP_DELETE,
        .handler   = routines_delete_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &routines_delete_uri);

    httpd_uri_t routines_stop_uri = {
        .uri       = "/api/v1/routines/stop",
        .method    = HTTP_POST,
        .handler   = routines_stop_post_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &routines_stop_uri);

    httpd_uri_t options_routines_uri = {
        .uri       = "/api/v1/routines",
        .method    = HTTP_OPTIONS,
        .handler   = options_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &options_routines_uri);

    httpd_uri_t options_routines_stop_uri = {
        .uri       = "/api/v1/routines/stop",
        .method    = HTTP_OPTIONS,
        .handler   = options_handler,
        .user_ctx  = NULL,
    };
    httpd_register_uri_handler(s_server, &options_routines_stop_uri);

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
