#include "local_server.h"
#include "board_config.h"
#include "cJSON.h"
#include "edge_routine_engine.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_timer.h"
#ifdef ESP_PLATFORM
#include "esp_wifi.h"
#endif
#include "factory_identity_v2.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "relay_manager.h"
#include "ota_manager.h"
#include "reset_button.h"
#include "switch_manager.h"
#include "time_sync_manager.h"
#include "nvs.h"
#include "nvs_flash.h"
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

static void inspect_and_inject_client_time(httpd_req_t *req, cJSON *body) {
  if (req) {
    char epoch_hdr[32];
    if (httpd_req_get_hdr_value_str(req, "X-Client-Epoch-Sec", epoch_hdr,
                                    sizeof(epoch_hdr)) == ESP_OK) {
      uint64_t sec = strtoull(epoch_hdr, NULL, 10);
      if (sec >= MIN_VALID_EPOCH) {
        time_sync_manager_inject_epoch(sec, "LOCAL_HTTP_HEADER");
      }
    }
  }
  if (body) {
    cJSON *ut = cJSON_GetObjectItem(body, "unix_time");
    if (!ut)
      ut = cJSON_GetObjectItem(body, "epoch");
    if (ut && cJSON_IsNumber(ut) && ut->valuedouble >= MIN_VALID_EPOCH) {
      time_sync_manager_inject_epoch((uint64_t)ut->valuedouble,
                                     "LOCAL_HTTP_BODY");
    }
  }
}

static const char *TAG = "EH_LOCAL_SRV";

static int get_sta_wifi_rssi(void) {
#ifdef ESP_PLATFORM
  wifi_ap_record_t ap_info;
  if (esp_wifi_sta_get_ap_info(&ap_info) == ESP_OK) {
    return (int)ap_info.rssi;
  }
#endif
  return -127;
}

static void add_active_routines_array(cJSON *root) {
  if (!root)
    return;
  size_t rt_count = 0;
  const edge_routine_t *rts = edge_routine_engine_get_routines(&rt_count);
  cJSON *active_arr = cJSON_CreateArray();
  if (rts && active_arr) {
    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
      if (rts[i].id[0] != '\0' && rts[i].enabled &&
          rts[i].runtime_state == ROUTINE_STATE_RUNNING) {
        cJSON *rt_obj = cJSON_CreateObject();
        if (rt_obj) {
          cJSON_AddStringToObject(rt_obj, "id", rts[i].id);
          cJSON_AddStringToObject(rt_obj, "name", rts[i].name);
          cJSON_AddNumberToObject(rt_obj, "channelIndex",
                                  (int)rts[i].channel_index);
          cJSON_AddNumberToObject(rt_obj, "remainingSec",
                                  (double)rts[i].remaining_sec);
          cJSON_AddBoolToObject(rt_obj, "isToggle", rts[i].is_toggle);
          cJSON_AddItemToArray(active_arr, rt_obj);
        }
      }
    }
  }
  cJSON_AddItemToObject(root, "activeRoutines", active_arr);
}

#ifndef EH_FIRMWARE_VERSION
#define EH_FIRMWARE_VERSION "1.1.0"
#endif

static httpd_handle_t s_server = NULL;
static TaskHandle_t s_udp_task = NULL;
static int s_udp_sock = -1;
static volatile bool s_udp_running = false;
static struct sockaddr_in s_last_client_addr;
static volatile bool s_has_client_addr = false;

#define EH_MAX_PEER_RULES 8
#define EH_NVS_PEER_NS "eh_peer_rules"
#define EH_NVS_PEER_KEY "rules_v1"
#define EH_PEER_BLOB_MAGIC 0x50454552U

typedef struct {
  char id[40];
  char trigger_device_id[48];
  uint8_t trigger_channel;
  int8_t trigger_state; /* 1 = ON, 0 = OFF, -1 = ANY */
  char action_device_id[48];
  char action_device_ip[24];
  uint8_t action_channel;
  bool action_power;
  bool is_toggle;
  bool enabled;
  uint8_t valid;
} eh_peer_rule_t;

typedef struct {
  uint32_t magic;
  uint32_t count;
  eh_peer_rule_t rules[EH_MAX_PEER_RULES];
} eh_peer_rules_blob_t;

static eh_peer_rule_t s_peer_rules[EH_MAX_PEER_RULES];
static bool s_peer_rules_loaded = false;
static bool s_prev_local_powers[EH_RELAY_CHANNEL_COUNT];
static bool s_prev_local_init = false;

typedef struct {
  char device_id[48];
  bool powers[4];
  bool initialized;
} remote_peer_state_t;

static remote_peer_state_t s_remote_peer_states[4];

static bool peer_id_matches(const char *a, const char *b) {
  if (!a || !b || a[0] == '\0' || b[0] == '\0') {
    return false;
  }
  char na[48] = {0};
  char nb[48] = {0};
  size_t ia = 0, ib = 0;
  for (size_t i = 0; a[i] != '\0' && ia < sizeof(na) - 1; i++) {
    if (isalnum((unsigned char)a[i])) {
      na[ia++] = (char)tolower((unsigned char)a[i]);
    }
  }
  for (size_t i = 0; b[i] != '\0' && ib < sizeof(nb) - 1; i++) {
    if (isalnum((unsigned char)b[i])) {
      nb[ib++] = (char)tolower((unsigned char)b[i]);
    }
  }
  if (ia == 0 || ib == 0) {
    return false;
  }
  if (strcmp(na, nb) == 0) {
    return true;
  }
  if (ia >= 6 && ib >= 6 &&
      (strstr(na, nb) != NULL || strstr(nb, na) != NULL)) {
    return true;
  }
  return false;
}

static void peer_rules_load_from_nvs(void) {
  if (s_peer_rules_loaded) {
    return;
  }
  s_peer_rules_loaded = true;
  memset(s_peer_rules, 0, sizeof(s_peer_rules));

  nvs_handle_t handle;
  if (nvs_open(EH_NVS_PEER_NS, NVS_READONLY, &handle) != ESP_OK) {
    return;
  }
  eh_peer_rules_blob_t *blob =
      (eh_peer_rules_blob_t *)calloc(1, sizeof(eh_peer_rules_blob_t));
  if (!blob) {
    nvs_close(handle);
    return;
  }
  size_t req_len = sizeof(eh_peer_rules_blob_t);
  esp_err_t err = nvs_get_blob(handle, EH_NVS_PEER_KEY, blob, &req_len);
  nvs_close(handle);

  if (err == ESP_OK && req_len == sizeof(eh_peer_rules_blob_t) &&
      blob->magic == EH_PEER_BLOB_MAGIC) {
    size_t n = blob->count <= EH_MAX_PEER_RULES ? blob->count : EH_MAX_PEER_RULES;
    size_t loaded = 0;
    for (size_t i = 0; i < n; i++) {
      if (blob->rules[i].valid && blob->rules[i].id[0] != '\0') {
        s_peer_rules[loaded++] = blob->rules[i];
      }
    }
    ESP_LOGI(TAG, "Loaded %u P2P peer rule(s) from NVS", (unsigned int)loaded);
  }
  free(blob);
}

static bool peer_rules_save_to_nvs(void) {
  peer_rules_load_from_nvs();
  eh_peer_rules_blob_t *blob =
      (eh_peer_rules_blob_t *)calloc(1, sizeof(eh_peer_rules_blob_t));
  if (!blob) {
    return false;
  }
  blob->magic = EH_PEER_BLOB_MAGIC;
  blob->count = EH_MAX_PEER_RULES;
  memcpy(blob->rules, s_peer_rules, sizeof(s_peer_rules));

  nvs_handle_t handle;
  esp_err_t err = nvs_open(EH_NVS_PEER_NS, NVS_READWRITE, &handle);
  if (err != ESP_OK) {
    free(blob);
    return false;
  }

  eh_peer_rules_blob_t *cur =
      (eh_peer_rules_blob_t *)calloc(1, sizeof(eh_peer_rules_blob_t));
  bool same = false;
  if (cur) {
    size_t cur_len = sizeof(eh_peer_rules_blob_t);
    if (nvs_get_blob(handle, EH_NVS_PEER_KEY, cur, &cur_len) == ESP_OK &&
        cur_len == sizeof(eh_peer_rules_blob_t) &&
        memcmp(cur, blob, sizeof(eh_peer_rules_blob_t)) == 0) {
      same = true;
    }
    free(cur);
  }

  if (!same) {
    err = nvs_set_blob(handle, EH_NVS_PEER_KEY, blob, sizeof(eh_peer_rules_blob_t));
    if (err == ESP_OK) {
      err = nvs_commit(handle);
    }
  }
  nvs_close(handle);
  free(blob);
  return (err == ESP_OK);
}

typedef struct {
  uint8_t channel;
  bool power;
  bool is_toggle;
} deferred_local_act_t;

static void deferred_local_act_task(void *arg) {
  deferred_local_act_t *act = (deferred_local_act_t *)arg;
  vTaskDelay(pdMS_TO_TICKS(15));
  if (act && act->channel >= 1 && act->channel <= EH_RELAY_CHANNEL_COUNT) {
    if (act->is_toggle) {
      relay_manager_toggle_power(act->channel, "PEER_RULE_LOCAL");
    } else {
      relay_manager_set_power(act->channel, act->power, "PEER_RULE_LOCAL");
    }
  }
  free(act);
  vTaskDelete(NULL);
}

static void dispatch_local_peer_action(uint8_t channel, bool power, bool is_toggle) {
  if (channel < 1 || channel > EH_RELAY_CHANNEL_COUNT) {
    return;
  }
  deferred_local_act_t *act =
      (deferred_local_act_t *)calloc(1, sizeof(deferred_local_act_t));
  if (!act) {
    return;
  }
  act->channel = channel;
  act->power = power;
  act->is_toggle = is_toggle;
  if (xTaskCreate(deferred_local_act_task, "peer_loc_act", 3072, act, 5, NULL) != pdPASS) {
    free(act);
  }
}

static void peer_rules_update_ip_for_device(const char *dev_id, const char *ip_str) {
  if (!dev_id || !ip_str || dev_id[0] == '\0' || ip_str[0] == '\0') {
    return;
  }
  peer_rules_load_from_nvs();
  bool updated = false;
  for (size_t i = 0; i < EH_MAX_PEER_RULES; i++) {
    if (s_peer_rules[i].valid &&
        peer_id_matches(s_peer_rules[i].action_device_id, dev_id) &&
        strcmp(s_peer_rules[i].action_device_ip, ip_str) != 0) {
      strncpy(s_peer_rules[i].action_device_ip, ip_str,
              sizeof(s_peer_rules[i].action_device_ip) - 1);
      s_peer_rules[i].action_device_ip[sizeof(s_peer_rules[i].action_device_ip) - 1] = '\0';
      updated = true;
    }
  }
  if (updated) {
    peer_rules_save_to_nvs();
  }
}

static const char *get_local_model_name(void) {
  static char s_model[32] = {0};
  if (s_model[0] != '\0')
    return s_model;
  const char *v = factory_identity_v2_get_variant();
  if (!v || !v[0]) {
    v = EH_PRODUCT_VARIANT;
  }
  const char *pt = factory_identity_v2_get_product_type();
  bool is_sk =
      (pt && (strstr(pt, "SOCKET") != NULL || strstr(pt, "socket") != NULL));
  bool is_em = (EH_FEATURE_ENERGY_MONITORING != 0);
  snprintf(s_model, sizeof(s_model), "%s-%s%s", is_sk ? "EH-SK" : "EH-SW", v,
           is_em ? "-EM" : "");
  return s_model;
}
#ifdef EH_MODEL_NAME
#undef EH_MODEL_NAME
#endif
#define EH_MODEL_NAME get_local_model_name()

#ifndef EH_FEATURE_ENERGY_MONITORING
#define EH_FEATURE_ENERGY_MONITORING 0
#endif

static void udp_discovery_task(void *pvParameters) {
  (void)pvParameters;
  char rx_buffer[640];
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
  setsockopt(s_udp_sock, SOL_SOCKET, SO_BROADCAST, &broadcast,
             sizeof(broadcast));

  struct timeval tv = {.tv_sec = 1, .tv_usec = 0};
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
    int len = recvfrom(s_udp_sock, rx_buffer, sizeof(rx_buffer) - 1, 0,
                       (struct sockaddr *)&source_addr, &socklen);

    if (len < 0) {
      continue;
    }

    rx_buffer[len] = '\0';

    cJSON *rx_json = cJSON_Parse(rx_buffer);
    if (!rx_json) {
      continue;
    }

    cJSON *cmd_item = cJSON_GetObjectItem(rx_json, "cmd");
    const char *cmd_str =
        (cmd_item && cJSON_IsString(cmd_item)) ? cmd_item->valuestring : "";

    // Passive time injection from discovery/client payload
    cJSON *ut_item = cJSON_GetObjectItem(rx_json, "unix_time");
    if (!ut_item)
      ut_item = cJSON_GetObjectItem(rx_json, "epoch");
    if (ut_item && cJSON_IsNumber(ut_item) &&
        ut_item->valuedouble >= MIN_VALID_EPOCH) {
      time_sync_manager_inject_epoch((uint64_t)ut_item->valuedouble,
                                     "UDP_DISCOVERY");
    }

    if (strcmp(cmd_str, "EH_DISCOVER") == 0) {
      if (source_addr.ss_family == AF_INET) {
        memcpy(&s_last_client_addr, &source_addr, sizeof(struct sockaddr_in));
        s_has_client_addr = true;
      }
      const factory_identity_v2_t *id = factory_identity_v2_get();
      const char *dev_id = id ? id->device_id : "unknown";
      int rssi = get_sta_wifi_rssi();

      char resp[300];
      char resp[360];
      snprintf(resp, sizeof(resp),
               "{\"cmd\":\"EH_DISCOVER_RESP\",\"deviceId\":\"%s\",\"model\":\"%"
               "s\",\"firmwareVersion\":\"%s\",\"channelCount\":%d,"
               "\"hasEnergyMetering\":%s,\"port\":80,\"status\":\"ok\"}",
               "\"hasEnergyMetering\":%s,\"rssi\":%d,\"port\":80,\"status\":\"ok\"}",
               dev_id, EH_MODEL_NAME, EH_FIRMWARE_VERSION,
               (int)EH_RELAY_CHANNEL_COUNT,
               (EH_FEATURE_ENERGY_MONITORING != 0) ? "true" : "false");
               (EH_FEATURE_ENERGY_MONITORING != 0) ? "true" : "false",
               rssi);

      sendto(s_udp_sock, resp, strlen(resp), 0, (struct sockaddr *)&source_addr,
             sizeof(source_addr));
      ESP_LOGI(TAG,
               "Responded to UDP discovery request from client for device %s",
               dev_id);
    } else if (strcmp(cmd_str, "P2P_ACTUATE") == 0) {
      // Fast-Path Direct P2P UDP Actuation (<2ms execution with zero socket
      // overhead). Strictly match exact cmd=="P2P_ACTUATE" so ACKs never loop.
      const factory_identity_v2_t *id = factory_identity_v2_get();
      const char *dev_id = id ? id->device_id : "unknown";
      cJSON *target_dev_item = cJSON_GetObjectItem(rx_json, "targetDeviceId");
      bool targeted_to_me = true;
      if (target_dev_item && cJSON_IsString(target_dev_item) &&
          target_dev_item->valuestring[0] != '\0') {
        targeted_to_me = peer_id_matches(target_dev_item->valuestring, dev_id);
      }

      if (targeted_to_me) {
        cJSON *ch_item = cJSON_GetObjectItem(rx_json, "channel");
        if (!ch_item)
          ch_item = cJSON_GetObjectItem(rx_json, "channelIndex");
        cJSON *pwr_item = cJSON_GetObjectItem(rx_json, "power");
        if (!pwr_item)
          pwr_item = cJSON_GetObjectItem(rx_json, "state");
        cJSON *tog_item = cJSON_GetObjectItem(rx_json, "isToggle");
        if (!tog_item)
          tog_item = cJSON_GetObjectItem(rx_json, "toggle");
        cJSON *seq_item = cJSON_GetObjectItem(rx_json, "seq");

        uint8_t target_ch = ch_item ? (uint8_t)ch_item->valueint : 1;
        bool is_toggle = tog_item ? cJSON_IsTrue(tog_item) : false;
        bool target_power = pwr_item ? cJSON_IsTrue(pwr_item) : true;
        const char *seq =
            (seq_item && seq_item->valuestring) ? seq_item->valuestring : "";

        if (target_ch >= 1 && target_ch <= EH_RELAY_CHANNEL_COUNT) {
          if (is_toggle) {
            relay_manager_toggle_power(target_ch, "P2P_UDP");
          } else {
            relay_manager_set_power(target_ch, target_power, "P2P_UDP");
          }
        }

        char resp[256];
        snprintf(resp, sizeof(resp),
                 "{\"cmd\":\"P2P_ACK\",\"seq\":\"%s\",\"deviceId\":\"%"
                 "s\",\"channel\":%d,\"power\":%s,\"status\":\"ok\"}",
                 seq, dev_id, (int)target_ch,
                 relay_manager_get_power(target_ch) ? "true" : "false");

        sendto(s_udp_sock, resp, strlen(resp), 0,
               (struct sockaddr *)&source_addr, sizeof(source_addr));
        ESP_LOGI(TAG,
                 "P2P Fast-Path UDP Actuate executed for CH%d (seq=%s) in <2ms",
                 target_ch, seq);
      }
    } else if ((strcmp(cmd_str, "EH_STATE_CHANGED") == 0 ||
                strcmp(cmd_str, "EH_BOOT_ANNOUNCE") == 0) &&
               source_addr.ss_family == AF_INET) {
      // Autonomous Peer Event Listener: evaluate rules when a peer device
      // broadcasts EH_STATE_CHANGED or EH_BOOT_ANNOUNCE on UDP port 4210
      cJSON *src_dev_item = cJSON_GetObjectItem(rx_json, "deviceId");
      const factory_identity_v2_t *self_id_obj = factory_identity_v2_get();
      const char *self_id = self_id_obj ? self_id_obj->device_id : "unknown";
      if (src_dev_item && cJSON_IsString(src_dev_item) &&
          src_dev_item->valuestring[0] != '\0' &&
          !peer_id_matches(src_dev_item->valuestring, self_id)) {
        char src_ip_str[24] = {0};
        inet_ntoa_r(((struct sockaddr_in *)&source_addr)->sin_addr,
                    src_ip_str, sizeof(src_ip_str));
        peer_rules_update_ip_for_device(src_dev_item->valuestring, src_ip_str);

        bool is_state_evt = (strcmp(cmd_str, "EH_STATE_CHANGED") == 0);
        cJSON *ch_arr = cJSON_GetObjectItem(rx_json, "channels");
        if (ch_arr && cJSON_IsArray(ch_arr)) {
          int slot = -1;
          for (int s = 0; s < 4; s++) {
            if (peer_id_matches(s_remote_peer_states[s].device_id,
                                src_dev_item->valuestring)) {
              slot = s;
              break;
            }
            if (slot < 0 && s_remote_peer_states[s].device_id[0] == '\0') {
              slot = s;
            }
          }
          bool cur_powers[4] = {false, false, false, false};
          bool seen_ch[4] = {false, false, false, false};
          int arr_len = cJSON_GetArraySize(ch_arr);
          for (int k = 0; k < arr_len; k++) {
            cJSON *it = cJSON_GetArrayItem(ch_arr, k);
            cJSON *ci = cJSON_GetObjectItem(it, "channelIndex");
            cJSON *pw = cJSON_GetObjectItem(it, "power");
            if (ci && pw && cJSON_IsNumber(ci)) {
              int idx = ci->valueint - 1;
              if (idx >= 0 && idx < 4) {
                cur_powers[idx] = cJSON_IsTrue(pw);
                seen_ch[idx] = true;
              }
            }
          }

          if (slot >= 0) {
            remote_peer_state_t *rps = &s_remote_peer_states[slot];
            if (rps->device_id[0] == '\0') {
              strncpy(rps->device_id, src_dev_item->valuestring,
                      sizeof(rps->device_id) - 1);
              rps->initialized = false;
            }
            bool ch_changed[4] = {false, false, false, false};
            for (int idx = 0; idx < 4; idx++) {
              if (seen_ch[idx]) {
                if (!rps->initialized) {
                  ch_changed[idx] = is_state_evt;
                } else {
                  ch_changed[idx] = (cur_powers[idx] != rps->powers[idx]);
                }
                rps->powers[idx] = cur_powers[idx];
              }
            }
            rps->initialized = true;

            if (is_state_evt) {
              peer_rules_load_from_nvs();
              for (size_t r_idx = 0; r_idx < EH_MAX_PEER_RULES; r_idx++) {
                eh_peer_rule_t *r = &s_peer_rules[r_idx];
                if (!r->valid || !r->enabled)
                  continue;
                if (r->trigger_channel < 1 || r->trigger_channel > 4)
                  continue;
                int t_idx = r->trigger_channel - 1;
                if (!seen_ch[t_idx] || !ch_changed[t_idx])
                  continue;
                if (!peer_id_matches(r->trigger_device_id,
                                     src_dev_item->valuestring))
                  continue;
                if (!peer_id_matches(r->action_device_id, self_id))
                  continue;
                bool cur_p = cur_powers[t_idx];
                if (r->trigger_state == -1 ||
                    (r->trigger_state == 1 && cur_p) ||
                    (r->trigger_state == 0 && !cur_p)) {
                  ESP_LOGI(TAG, "Peer rule '%s' matched remote event from %s CH%d",
                           r->id, src_dev_item->valuestring, r->trigger_channel);
                  dispatch_local_peer_action(r->action_channel, r->action_power,
                                             r->is_toggle);
                }
              }
            }
          }
        }
      }
    }

    cJSON_Delete(rx_json);
  }

  if (s_udp_sock >= 0) {
    close(s_udp_sock);
    s_udp_sock = -1;
  }
  s_udp_task = NULL;
  vTaskDelete(NULL);
}

void local_server_broadcast_state(const bool *powers, uint8_t count) {
  if (!powers || count == 0) {
    return;
  }

  bool changed[EH_RELAY_CHANNEL_COUNT];
  for (uint8_t i = 0; i < count && i < EH_RELAY_CHANNEL_COUNT; i++) {
    changed[i] = !s_prev_local_init || (powers[i] != s_prev_local_powers[i]);
    s_prev_local_powers[i] = powers[i];
  }
  s_prev_local_init = true;

  if (s_udp_sock < 0 || !s_udp_running) {
    return;
  }

  const factory_identity_v2_t *id = factory_identity_v2_get();
  const char *dev_id = id ? id->device_id : "unknown";

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "cmd", "EH_STATE_CHANGED");
  cJSON_AddStringToObject(root, "deviceId", dev_id);
  cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
  cJSON_AddNumberToObject(root, "channelCount", (int)EH_RELAY_CHANNEL_COUNT);
  cJSON_AddBoolToObject(root, "hasEnergyMetering",
                        (EH_FEATURE_ENERGY_MONITORING != 0));
  cJSON_AddNumberToObject(root, "rssi", get_sta_wifi_rssi());
  cJSON *arr = cJSON_CreateArray();
  for (int i = 0; i < count; i++) {
    cJSON *ch = cJSON_CreateObject();
    cJSON_AddNumberToObject(ch, "channelIndex", i + 1);
    cJSON_AddBoolToObject(ch, "power", powers[i]);
    cJSON_AddItemToArray(arr, ch);
  }
  cJSON_AddItemToObject(root, "channels", arr);

  size_t rt_count = 0;
  const edge_routine_t *rts = edge_routine_engine_get_routines(&rt_count);
  cJSON *active_arr = cJSON_CreateArray();
  if (rts && active_arr) {
    for (size_t i = 0; i < MAX_EDGE_ROUTINES; i++) {
      if (rts[i].id[0] != '\0' && rts[i].enabled &&
          rts[i].runtime_state == ROUTINE_STATE_RUNNING) {
        cJSON *rt_obj = cJSON_CreateObject();
        if (rt_obj) {
          cJSON_AddStringToObject(rt_obj, "id", rts[i].id);
          cJSON_AddStringToObject(rt_obj, "name", rts[i].name);
          cJSON_AddNumberToObject(rt_obj, "channelIndex",
                                  (int)rts[i].channel_index);
          cJSON_AddNumberToObject(rt_obj, "remainingSec",
                                  (double)rts[i].remaining_sec);
          cJSON_AddBoolToObject(rt_obj, "isToggle", rts[i].is_toggle);
          cJSON_AddItemToArray(active_arr, rt_obj);
        }
      }
    }
  }
  cJSON_AddItemToObject(root, "activeRoutines", active_arr);
  add_active_routines_array(root);

  char *str = cJSON_PrintUnformatted(root);
  if (str) {
    struct sockaddr_in bcast_addr;
    memset(&bcast_addr, 0, sizeof(bcast_addr));
    bcast_addr.sin_family = AF_INET;
    bcast_addr.sin_port = htons(4210);
    bcast_addr.sin_addr.s_addr = htonl(INADDR_BROADCAST); // 255.255.255.255

    // Dual transmission: general subnet broadcast + direct unicast to connected
    // phone
    sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&bcast_addr,
           sizeof(bcast_addr));
    if (s_has_client_addr) {
      struct sockaddr_in client_dest;
      memcpy(&client_dest, &s_last_client_addr, sizeof(client_dest));
      client_dest.sin_port = htons(4210);
      sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&client_dest,
             sizeof(client_dest));
    }

    ESP_LOGI(TAG,
             "Broadcasted real-time state change over UDP port 4210 (instant "
             "sync): %s",
             str);
    free(str);
  }
  cJSON_Delete(root);

  // Autonomous On-Chip P2P Cross-Device Rule Evaluation (zero app/cloud dependency)
  peer_rules_load_from_nvs();
  for (size_t i = 0; i < EH_MAX_PEER_RULES; i++) {
    eh_peer_rule_t *r = &s_peer_rules[i];
    if (!r->valid || !r->enabled)
      continue;
    if (r->trigger_channel < 1 || r->trigger_channel > count ||
        r->trigger_channel > EH_RELAY_CHANNEL_COUNT)
      continue;
    int t_idx = r->trigger_channel - 1;
    if (!changed[t_idx])
      continue;
    if (!peer_id_matches(r->trigger_device_id, dev_id))
      continue;
    bool cur_p = powers[t_idx];
    if (r->trigger_state == -1 || (r->trigger_state == 1 && cur_p) ||
        (r->trigger_state == 0 && !cur_p)) {
      ESP_LOGI(TAG, "Autonomous P2P rule '%s' fired: CH%d=%s -> %s (%s) CH%d",
               r->id, r->trigger_channel, cur_p ? "ON" : "OFF",
               r->action_device_id, r->action_device_ip, r->action_channel);
      if (peer_id_matches(r->action_device_id, dev_id)) {
        if (r->action_channel != r->trigger_channel) {
          dispatch_local_peer_action(r->action_channel, r->action_power,
                                     r->is_toggle);
        }
      } else if (r->action_device_ip[0] != '\0') {
        local_server_send_p2p_actuate_target(
            r->action_device_ip, r->action_device_id, r->action_channel,
            r->action_power, r->is_toggle);
      }
    }
  }
}

void local_server_broadcast_boot_announce(const bool *powers, uint8_t count) {
  if (s_udp_sock < 0 || !s_udp_running) {
    return;
  }

  const factory_identity_v2_t *id = factory_identity_v2_get();
  const char *dev_id = id ? id->device_id : "unknown";

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "cmd", "EH_BOOT_ANNOUNCE");
  cJSON_AddStringToObject(root, "deviceId", dev_id);
  cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
  cJSON_AddStringToObject(root, "firmwareVersion", EH_FIRMWARE_VERSION);
  cJSON_AddNumberToObject(root, "channelCount", (int)EH_RELAY_CHANNEL_COUNT);
  cJSON_AddBoolToObject(root, "hasEnergyMetering",
                        (EH_FEATURE_ENERGY_MONITORING != 0));
  cJSON_AddNumberToObject(root, "rssi", get_sta_wifi_rssi());
  cJSON_AddNumberToObject(root, "port", 80);
  cJSON_AddStringToObject(root, "status", "ok");

  if (powers && count > 0) {
    cJSON *arr = cJSON_CreateArray();
    for (int i = 0; i < count; i++) {
      cJSON *ch = cJSON_CreateObject();
      cJSON_AddNumberToObject(ch, "channelIndex", i + 1);
      cJSON_AddBoolToObject(ch, "power", powers[i]);
      cJSON_AddItemToArray(arr, ch);
    }
    cJSON_AddItemToObject(root, "channels", arr);
  }

  char *str = cJSON_PrintUnformatted(root);
  if (str) {
    struct sockaddr_in bcast_addr;
    memset(&bcast_addr, 0, sizeof(bcast_addr));
    bcast_addr.sin_family = AF_INET;
    bcast_addr.sin_port = htons(4210);
    bcast_addr.sin_addr.s_addr = htonl(INADDR_BROADCAST); // 255.255.255.255

    // Broadcast to general subnet
    sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&bcast_addr,
           sizeof(bcast_addr));
    if (s_has_client_addr) {
      struct sockaddr_in client_dest;
      memcpy(&client_dest, &s_last_client_addr, sizeof(client_dest));
      client_dest.sin_port = htons(4210);
      sendto(s_udp_sock, str, strlen(str), 0, (struct sockaddr *)&client_dest,
             sizeof(client_dest));
    }

    ESP_LOGI(TAG, "Broadcasted boot announcement over UDP port 4210: %s", str);
    free(str);
  }
  cJSON_Delete(root);
}

bool local_server_send_p2p_actuate_target(const char *target_ip,
                                          const char *target_device_id,
                                          uint8_t target_channel, bool power,
                                          bool is_toggle) {
  if (s_udp_sock < 0 || !s_udp_running || !target_ip ||
      strlen(target_ip) == 0) {
    return false;
  }

  struct sockaddr_in dest_addr;
  memset(&dest_addr, 0, sizeof(dest_addr));
  dest_addr.sin_family = AF_INET;
  dest_addr.sin_port = htons(4210);
  dest_addr.sin_addr.s_addr = inet_addr(target_ip);

  char payload[256];
  if (target_device_id && target_device_id[0] != '\0') {
    snprintf(payload, sizeof(payload),
             "{\"cmd\":\"P2P_ACTUATE\",\"targetDeviceId\":\"%s\",\"channel\":%"
             "d,\"power\":%s,\"isToggle\":%s,\"seq\":\"p2p_%u\"}",
             target_device_id, (int)target_channel, power ? "true" : "false",
             is_toggle ? "true" : "false",
             (unsigned int)(esp_timer_get_time() & 0xFFFF));
  } else {
    snprintf(payload, sizeof(payload),
             "{\"cmd\":\"P2P_ACTUATE\",\"channel\":%d,\"power\":%s,\"isToggle\":%"
             "s,\"seq\":\"p2p_%u\"}",
             (int)target_channel, power ? "true" : "false",
             is_toggle ? "true" : "false",
             (unsigned int)(esp_timer_get_time() & 0xFFFF));
  }

  int sent = sendto(s_udp_sock, payload, strlen(payload), 0,
                    (struct sockaddr *)&dest_addr, sizeof(dest_addr));
  if (sent > 0) {
    ESP_LOGI(TAG, "Sent P2P Fast-Path UDP to %s:4210 (CH%d power=%d): %s",
             target_ip, (int)target_channel, power ? 1 : 0, payload);
    return true;
  }
  return false;
}

bool local_server_send_p2p_actuate(const char *target_ip,
                                   uint8_t target_channel, bool power,
                                   bool is_toggle) {
  return local_server_send_p2p_actuate_target(target_ip, NULL, target_channel,
                                              power, is_toggle);
}

#ifdef ESP_PLATFORM
typedef struct {
  bool powers[EH_RELAY_CHANNEL_COUNT];
  uint8_t count;
} boot_announce_burst_ctx_t;

static void boot_announce_burst_task(void *arg) {
  boot_announce_burst_ctx_t *ctx = (boot_announce_burst_ctx_t *)arg;
  for (int i = 0; i < 3; i++) {
    local_server_broadcast_boot_announce(ctx->powers, ctx->count);
    if (i < 2) {
      vTaskDelay(pdMS_TO_TICKS(1500));
    }
  }
  free(ctx);
  vTaskDelete(NULL);
}

void local_server_start_boot_announce_burst(const bool *powers, uint8_t count) {
  boot_announce_burst_ctx_t *ctx =
      (boot_announce_burst_ctx_t *)calloc(1, sizeof(boot_announce_burst_ctx_t));
  if (ctx) {
    if (powers && count > 0) {
      uint8_t copy_count =
          (count <= EH_RELAY_CHANNEL_COUNT) ? count : EH_RELAY_CHANNEL_COUNT;
      memcpy(ctx->powers, powers, copy_count * sizeof(bool));
      ctx->count = copy_count;
    }
    if (xTaskCreate(boot_announce_burst_task, "boot_ann_burst", 4096, ctx, 5,
                    NULL) != pdPASS) {
      local_server_broadcast_boot_announce(powers, count);
      free(ctx);
    }
  } else {
    local_server_broadcast_boot_announce(powers, count);
  }
}
#else
void local_server_start_boot_announce_burst(const bool *powers, uint8_t count) {
  for (int i = 0; i < 3; i++) {
    local_server_broadcast_boot_announce(powers, count);
  }
}
#endif

static void set_cors_headers(httpd_req_t *req) {
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Methods",
                     "GET, POST, DELETE, OPTIONS");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Headers",
                     "Content-Type, Authorization");
}

/* OPTIONS handler for CORS pre-flight requests */
static esp_err_t options_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_status(req, "204 No Content");
  httpd_resp_send(req, NULL, 0);
  return ESP_OK;
}

/* GET /api/v1/ping - Health check & LAN discovery */
static esp_err_t ping_get_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  const factory_identity_v2_t *id = factory_identity_v2_get();
  const char *dev_id = id ? id->device_id : "unknown";

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "status", "ok");
  cJSON_AddStringToObject(root, "deviceId", dev_id);
  cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
  cJSON_AddStringToObject(root, "firmwareVersion", EH_FIRMWARE_VERSION);
  cJSON_AddNumberToObject(root, "channelCount", EH_RELAY_CHANNEL_COUNT);
  cJSON_AddBoolToObject(root, "hasEnergyMetering",
                        (EH_FEATURE_ENERGY_MONITORING != 0));
  cJSON_AddNumberToObject(root, "rssi", get_sta_wifi_rssi());
  cJSON_AddBoolToObject(root, "lanMode", true);
  cJSON_AddNumberToObject(root, "uptimeMs",
                          (double)(esp_timer_get_time() / 1000));

  const char *response_str = cJSON_PrintUnformatted(root);
  httpd_resp_sendstr(req, response_str);

  free((void *)response_str);
  cJSON_Delete(root);
  return ESP_OK;
}

/* GET /api/v1/state - Query live relay states */
static esp_err_t state_get_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  const factory_identity_v2_t *id = factory_identity_v2_get();
  const char *dev_id = id ? id->device_id : "unknown";

  inspect_and_inject_client_time(req, NULL);

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "deviceId", dev_id);
  cJSON_AddStringToObject(root, "model", EH_MODEL_NAME);
  cJSON_AddStringToObject(root, "firmwareVersion", EH_FIRMWARE_VERSION);
  cJSON_AddNumberToObject(root, "channelCount", EH_RELAY_CHANNEL_COUNT);
  cJSON_AddBoolToObject(root, "hasEnergyMetering",
                        (EH_FEATURE_ENERGY_MONITORING != 0));
  cJSON_AddNumberToObject(root, "rssi", get_sta_wifi_rssi());
  cJSON_AddBoolToObject(root, "online", true);
  cJSON_AddBoolToObject(root, "timeSynced", time_sync_manager_is_synced());
  cJSON_AddNumberToObject(root, "epoch", (double)time(NULL));

  cJSON *channels = cJSON_AddArrayToObject(root, "channels");
  for (int i = 1; i <= EH_RELAY_CHANNEL_COUNT; i++) {
    cJSON *ch = cJSON_CreateObject();
    cJSON_AddNumberToObject(ch, "channelIndex", i);
    cJSON_AddBoolToObject(ch, "power", relay_manager_get_power((uint8_t)i));
    cJSON_AddItemToArray(channels, ch);
  }
  add_active_routines_array(root);

  const char *response_str = cJSON_PrintUnformatted(root);
  httpd_resp_sendstr(req, response_str);

  free((void *)response_str);
  cJSON_Delete(root);
  return ESP_OK;
}

/* POST /api/v1/control - Direct local LAN relay actuation */
static esp_err_t control_post_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

#ifdef ESP_PLATFORM
  int sockfd = httpd_req_to_sockfd(req);
  if (sockfd >= 0) {
    struct sockaddr_in peer;
    socklen_t peer_len = sizeof(peer);
    if (getpeername(sockfd, (struct sockaddr *)&peer, &peer_len) == 0 &&
        peer.sin_family == AF_INET) {
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

  cJSON *root = cJSON_Parse(buf);
  if (!root) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON payload");
    return ESP_FAIL;
  }

  inspect_and_inject_client_time(req, root);

  cJSON *ch_item = cJSON_GetObjectItem(root, "channel");
  if (!ch_item)
    ch_item = cJSON_GetObjectItem(root, "channelIndex");

  cJSON *pwr_item = cJSON_GetObjectItem(root, "power");
  if (!pwr_item)
    pwr_item = cJSON_GetObjectItem(root, "value");
  if (!pwr_item)
    pwr_item = cJSON_GetObjectItem(root, "enabled");

  cJSON *toggle_item = cJSON_GetObjectItem(root, "toggle");
  cJSON *action_item = cJSON_GetObjectItem(root, "action");
  bool is_toggle = false;
  if (toggle_item && (cJSON_IsTrue(toggle_item) ||
                      (cJSON_IsString(toggle_item) &&
                       strcmp(toggle_item->valuestring, "toggle") == 0))) {
    is_toggle = true;
  }
  if (action_item && cJSON_IsString(action_item) &&
      strcmp(action_item->valuestring, "toggle") == 0) {
    is_toggle = true;
  }

  if (!ch_item || !cJSON_IsNumber(ch_item) ||
      (!is_toggle && (!pwr_item || !cJSON_IsBool(pwr_item)))) {
    cJSON_Delete(root);
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST,
                        "Missing channel or power parameters");
    return ESP_FAIL;
  }

  uint8_t channel = (uint8_t)ch_item->valueint;
  bool success = false;
  if (is_toggle) {
    ESP_LOGI(TAG, "LOCAL_LAN_COMMAND_RECEIVED channel=%d action=TOGGLE",
             channel);
    success = relay_manager_toggle_power(channel, "LOCAL_HTTP");
  } else {
    bool power = cJSON_IsTrue(pwr_item);
    ESP_LOGI(TAG, "LOCAL_LAN_COMMAND_RECEIVED channel=%d power=%s", channel,
             power ? "ON" : "OFF");
    if (!power) {
      // Dual Emergency Stop: Turning off channel immediately disarms edge
      // routine timer on that channel
      edge_routine_engine_emergency_stop(channel, "LOCAL_HTTP_OFF");
    }
    success = relay_manager_set_power(channel, power, "LOCAL_HTTP");
  }

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddBoolToObject(resp, "success", success);
  cJSON_AddNumberToObject(resp, "channel", channel);
  cJSON_AddBoolToObject(resp, "power", relay_manager_get_power(channel));
  cJSON_AddStringToObject(resp, "mode", "LOCAL_LAN");

  const char *response_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, response_str);

  free((void *)response_str);
  cJSON_Delete(resp);
  cJSON_Delete(root);
  return ESP_OK;
}

/* POST /api/v1/reset - Remote Factory Reset & Wipe Wi-Fi Credentials */
static esp_err_t reset_post_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddBoolToObject(resp, "success", true);
  cJSON_AddStringToObject(
      resp, "message",
      "Factory reset initiated. Device entering BLE provisioning.");

  const char *response_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, response_str);

  free((void *)response_str);
  cJSON_Delete(resp);

  ESP_LOGW(TAG, "REMOTE_FACTORY_RESET_TRIGGERED: Erasing Wi-Fi credentials, "
                "edge routines, and resetting device...");
  edge_routine_engine_clear_all();
  reset_button_trigger_factory_reset();
  return ESP_OK;
}

/* GET /api/v1/routines - Query configured and active edge routines */
static esp_err_t routines_get_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  inspect_and_inject_client_time(req, NULL);

  char *response_str = edge_routine_engine_to_json_string();
  if (!response_str) {
    httpd_resp_sendstr(req, "[]");
  } else {
    httpd_resp_sendstr(req, response_str);
    free(response_str);
  }
  return ESP_OK;
}

/* POST /api/v1/routines - Create or update edge routine (wear-leveled NVS
 * persistence) */
static esp_err_t routines_post_handler(httpd_req_t *req) {
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

  cJSON *root = cJSON_Parse(buf);
  if (!root) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON payload");
    return ESP_FAIL;
  }

  inspect_and_inject_client_time(req, root);

  cJSON *id_item = cJSON_GetObjectItem(root, "id");
  cJSON *name_item = cJSON_GetObjectItem(root, "name");
  cJSON *ch_item = cJSON_GetObjectItem(root, "channel");
  if (!ch_item)
    ch_item = cJSON_GetObjectItem(root, "channelIndex");
  cJSON *pwr_item = cJSON_GetObjectItem(root, "power");
  if (!pwr_item)
    pwr_item = cJSON_GetObjectItem(root, "targetPower");
  cJSON *toggle_item = cJSON_GetObjectItem(root, "isToggle");
  if (!toggle_item)
    toggle_item = cJSON_GetObjectItem(root, "toggle");
  cJSON *trig_item = cJSON_GetObjectItem(root, "triggerType");
  cJSON *dur_item = cJSON_GetObjectItem(root, "durationSec");
  if (!dur_item)
    dur_item = cJSON_GetObjectItem(root, "duration");
  if (!dur_item)
    dur_item = cJSON_GetObjectItem(root, "pulseDurationSeconds");
  if (!dur_item)
    dur_item = cJSON_GetObjectItem(root, "pulseSec");
  cJSON *en_item = cJSON_GetObjectItem(root, "enabled");

  if (!id_item || !cJSON_IsString(id_item) || !ch_item ||
      !cJSON_IsNumber(ch_item)) {
    cJSON_Delete(root);
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST,
                        "Missing required id or channel");
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

  cJSON *hr_item = cJSON_GetObjectItem(root, "hour");
  cJSON *min_item = cJSON_GetObjectItem(root, "minute");
  cJSON *days_item = cJSON_GetObjectItem(root, "daysMask");
  if (!days_item)
    days_item = cJSON_GetObjectItem(root, "days");

  if (hr_item && cJSON_IsNumber(hr_item))
    r.hour = (uint8_t)hr_item->valueint;
  if (min_item && cJSON_IsNumber(min_item))
    r.minute = (uint8_t)min_item->valueint;
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

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddBoolToObject(resp, "success", success);
  cJSON_AddStringToObject(resp, "id", r.id);
  const char *resp_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, resp_str);
  free((void *)resp_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* DELETE /api/v1/routines - Delete edge routine by ID (via query parameter or
 * JSON body) */
static esp_err_t routines_delete_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  char routine_id[ROUTINE_ID_MAX_LEN] = {0};

  // 1. Try URL query parameter (?id=xxx)
  char q_buf[128];
  if (httpd_req_get_url_query_str(req, q_buf, sizeof(q_buf)) == ESP_OK) {
    httpd_query_key_value(q_buf, "id", routine_id, sizeof(routine_id));
  }

  // 2. Try JSON body if query didn't provide id
  if (routine_id[0] == '\0' && req->content_len > 0 &&
      req->content_len <= 128) {
    char buf[129];
    int ret = httpd_req_recv(req, buf, req->content_len);
    if (ret > 0) {
      buf[ret] = '\0';
      cJSON *root = cJSON_Parse(buf);
      if (root) {
        cJSON *id_item = cJSON_GetObjectItem(root, "id");
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
    ESP_LOGI(TAG,
             "LOCAL_HTTP: Routine '%s' deleted from edge engine (success=%d)",
             routine_id, success);
  } else {
    ESP_LOGW(TAG, "LOCAL_HTTP: Delete routine failed, missing 'id' parameter");
  }

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddBoolToObject(resp, "success", success);
  cJSON_AddStringToObject(resp, "id", routine_id);
  const char *resp_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, resp_str);
  free((void *)resp_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* POST /api/v1/routines/stop - Dual Emergency Stop (Local LAN) */
static esp_err_t routines_stop_post_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  uint8_t channel = 0; // 0 = all channels by default
  if (req->content_len > 0 && req->content_len <= 128) {
    char buf[129];
    int ret = httpd_req_recv(req, buf, req->content_len);
    if (ret > 0) {
      buf[ret] = '\0';
      cJSON *root = cJSON_Parse(buf);
      if (root) {
        cJSON *ch_item = cJSON_GetObjectItem(root, "channel");
        if (!ch_item)
          ch_item = cJSON_GetObjectItem(root, "channelIndex");
        if (ch_item && cJSON_IsNumber(ch_item)) {
          channel = (uint8_t)ch_item->valueint;
        }
        cJSON_Delete(root);
      }
    }
  }

  ESP_LOGW(TAG, "LOCAL_LAN_EMERGENCY_STOP executed for channel %d", channel);
  edge_routine_engine_emergency_stop(channel, "LOCAL_HTTP_STOP");

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddBoolToObject(resp, "success", true);
  cJSON_AddNumberToObject(resp, "channel", channel);
  cJSON_AddStringToObject(resp, "message", "Emergency stop executed");
  const char *resp_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, resp_str);
  free((void *)resp_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* GET /api/v1/settings - Query device settings (Power-on behavior & Child Lock)
 */
static esp_err_t settings_get_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "status", "ok");
  cJSON_AddNumberToObject(root, "powerOnMode",
                          relay_manager_get_power_on_mode());
  cJSON_AddBoolToObject(root, "childLock", switch_manager_get_child_lock());

  const char *str = cJSON_PrintUnformatted(root);
  httpd_resp_sendstr(req, str);
  free((void *)str);
  cJSON_Delete(root);
  return ESP_OK;
}

/* POST /api/v1/settings/power-on - Configure power-on behavior (0=OFF, 1=ON,
 * 2=RESTORE) */
static esp_err_t settings_power_on_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  char buf[128];
  int ret = httpd_req_recv(req, buf, sizeof(buf) - 1);
  if (ret <= 0) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }
  buf[ret] = '\0';

  cJSON *root = cJSON_Parse(buf);
  if (!root) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON");
    return ESP_FAIL;
  }

  cJSON *mode_item = cJSON_GetObjectItem(root, "mode");
  if (!mode_item || !cJSON_IsNumber(mode_item)) {
    cJSON_Delete(root);
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing mode");
    return ESP_FAIL;
  }

  uint8_t mode = (uint8_t)mode_item->valueint;
  relay_manager_set_power_on_mode(mode);
  cJSON_Delete(root);

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddStringToObject(resp, "status", "ok");
  cJSON_AddNumberToObject(resp, "powerOnMode",
                          relay_manager_get_power_on_mode());
  cJSON_AddStringToObject(resp, "message", "Power-on behavior updated");
  const char *str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, str);
  free((void *)str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* POST /api/v1/settings/child-lock - Enable/disable physical switch lockout */
static esp_err_t settings_child_lock_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  char buf[128];
  int ret = httpd_req_recv(req, buf, sizeof(buf) - 1);
  if (ret <= 0) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }
  buf[ret] = '\0';

  cJSON *root = cJSON_Parse(buf);
  if (!root) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON");
    return ESP_FAIL;
  }

  cJSON *en_item = cJSON_GetObjectItem(root, "enabled");
  if (!en_item || !cJSON_IsBool(en_item)) {
    cJSON_Delete(root);
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing enabled boolean");
    return ESP_FAIL;
  }

  bool enabled = cJSON_IsTrue(en_item);
  switch_manager_set_child_lock(enabled);
  cJSON_Delete(root);

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddStringToObject(resp, "status", "ok");
  cJSON_AddBoolToObject(resp, "childLock", switch_manager_get_child_lock());
  cJSON_AddStringToObject(resp, "message", "Child lock configuration updated");
  const char *str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, str);
  free((void *)str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* POST /api/v1/ota/start - Initiate real HTTP/HTTPS OTA update over LAN or Hub */
static esp_err_t ota_start_post_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  int total_len = req->content_len;
  if (total_len <= 0 || total_len > 768) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid OTA payload size");
    return ESP_FAIL;
  }

  char buf[769];
  int cur_len = 0;
  while (cur_len < total_len) {
    int received = httpd_req_recv(req, buf + cur_len, total_len - cur_len);
    if (received <= 0) {
      return ESP_FAIL;
    }
    cur_len += received;
  }
  buf[total_len] = '\0';

  cJSON *root = cJSON_Parse(buf);
  if (!root) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON payload");
    return ESP_FAIL;
  }

  cJSON *url_item = cJSON_GetObjectItem(root, "downloadUrl");
  cJSON *ver_item = cJSON_GetObjectItem(root, "version");
  cJSON *sha_item = cJSON_GetObjectItem(root, "sha256");
  cJSON *rel_item = cJSON_GetObjectItem(root, "releaseId");
  cJSON *sz_item = cJSON_GetObjectItem(root, "binarySizeBytes");

  if (!url_item || !cJSON_IsString(url_item) || strlen(url_item->valuestring) == 0) {
    cJSON_Delete(root);
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing downloadUrl");
    return ESP_FAIL;
  }

  eh_ota_manifest_t manifest;
  memset(&manifest, 0, sizeof(manifest));
  strncpy(manifest.download_url, url_item->valuestring, sizeof(manifest.download_url) - 1);
  if (ver_item && cJSON_IsString(ver_item)) {
    strncpy(manifest.version, ver_item->valuestring, sizeof(manifest.version) - 1);
  } else {
    strncpy(manifest.version, "1.1.0", sizeof(manifest.version) - 1);
  }
  if (sha_item && cJSON_IsString(sha_item)) {
    strncpy(manifest.sha256, sha_item->valuestring, sizeof(manifest.sha256) - 1);
  }
  if (rel_item && cJSON_IsString(rel_item)) {
    strncpy(manifest.release_id, rel_item->valuestring, sizeof(manifest.release_id) - 1);
  }
  if (sz_item && cJSON_IsNumber(sz_item) && sz_item->valuedouble > 0) {
    manifest.binary_size_bytes = (size_t)sz_item->valuedouble;
  }

  bool ok = ota_manager_start_update_async(&manifest);
  cJSON_Delete(root);

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddBoolToObject(resp, "success", ok);
  cJSON_AddStringToObject(resp, "status", ok ? "OTA_STARTED" : "OTA_REJECTED");
  if (!ok) {
    cJSON_AddStringToObject(resp, "error", ota_manager_get_last_error());
  }
  const char *response_str = cJSON_PrintUnformatted(resp);
  if (!ok) {
    httpd_resp_set_status(req, "400 Bad Request");
  }
  httpd_resp_sendstr(req, response_str);
  free((void *)response_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* GET /api/v1/ota/status - Live OTA state & progress */
static esp_err_t ota_status_get_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  eh_ota_state_t st = ota_manager_get_state();
  const char *state_str = "IDLE";
  switch (st) {
    case EH_OTA_STATE_DOWNLOADING: state_str = "DOWNLOADING"; break;
    case EH_OTA_STATE_VERIFYING:   state_str = "VERIFYING"; break;
    case EH_OTA_STATE_INSTALLING:  state_str = "INSTALLING"; break;
    case EH_OTA_STATE_REBOOTING:   state_str = "REBOOTING"; break;
    case EH_OTA_STATE_ROLLED_BACK: state_str = "ROLLED_BACK"; break;
    case EH_OTA_STATE_FAILED:      state_str = "FAILED"; break;
    default: break;
  }

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddStringToObject(resp, "state", state_str);
  cJSON_AddNumberToObject(resp, "progressPercent", ota_manager_get_progress());
  cJSON_AddStringToObject(resp, "firmwareVersion", EH_FIRMWARE_VERSION);
  cJSON_AddStringToObject(resp, "lastError", ota_manager_get_last_error());
  const char *response_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, response_str);
  free((void *)response_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* GET /api/v1/peer-rules - List persisted autonomous P2P cross-device rules */
static esp_err_t peer_rules_get_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");
  peer_rules_load_from_nvs();

  cJSON *resp = cJSON_CreateObject();
  cJSON *arr = cJSON_CreateArray();
  for (size_t i = 0; i < EH_MAX_PEER_RULES; i++) {
    eh_peer_rule_t *r = &s_peer_rules[i];
    if (!r->valid || r->id[0] == '\0')
      continue;
    cJSON *item = cJSON_CreateObject();
    cJSON_AddStringToObject(item, "id", r->id);
    cJSON_AddStringToObject(item, "triggerDeviceId", r->trigger_device_id);
    cJSON_AddNumberToObject(item, "triggerChannel", r->trigger_channel);
    if (r->trigger_state == -1) {
      cJSON_AddNullToObject(item, "triggerState");
    } else {
      cJSON_AddBoolToObject(item, "triggerState", r->trigger_state == 1);
    }
    cJSON_AddStringToObject(item, "actionDeviceId", r->action_device_id);
    cJSON_AddStringToObject(item, "actionDeviceIp", r->action_device_ip);
    cJSON_AddNumberToObject(item, "actionChannel", r->action_channel);
    cJSON_AddBoolToObject(item, "actionPower", r->action_power);
    cJSON_AddBoolToObject(item, "isToggle", r->is_toggle);
    cJSON_AddBoolToObject(item, "enabled", r->enabled);
    cJSON_AddItemToArray(arr, item);
  }
  cJSON_AddItemToObject(resp, "rules", arr);

  const char *str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, str);
  free((void *)str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* POST /api/v1/peer-rules - Upsert autonomous P2P cross-device rule to NVS */
static esp_err_t peer_rules_post_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  int total_len = req->content_len;
  if (total_len <= 0 || total_len > 768) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid peer rule payload size");
    return ESP_FAIL;
  }

  char buf[769];
  int cur_len = 0;
  while (cur_len < total_len) {
    int received = httpd_req_recv(req, buf + cur_len, total_len - cur_len);
    if (received <= 0) {
      return ESP_FAIL;
    }
    cur_len += received;
  }
  buf[total_len] = '\0';

  cJSON *root = cJSON_Parse(buf);
  if (!root) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid JSON payload");
    return ESP_FAIL;
  }

  cJSON *id_item = cJSON_GetObjectItem(root, "id");
  cJSON *td_item = cJSON_GetObjectItem(root, "triggerDeviceId");
  cJSON *tc_item = cJSON_GetObjectItem(root, "triggerChannel");
  cJSON *ts_item = cJSON_GetObjectItem(root, "triggerState");
  cJSON *ad_item = cJSON_GetObjectItem(root, "actionDeviceId");
  cJSON *aip_item = cJSON_GetObjectItem(root, "actionDeviceIp");
  cJSON *ac_item = cJSON_GetObjectItem(root, "actionChannel");
  cJSON *ap_item = cJSON_GetObjectItem(root, "actionPower");
  cJSON *acmd_item = cJSON_GetObjectItem(root, "actionCommand");
  cJSON *tog_item = cJSON_GetObjectItem(root, "isToggle");
  cJSON *en_item = cJSON_GetObjectItem(root, "enabled");

  if (!id_item || !cJSON_IsString(id_item) || !td_item || !cJSON_IsString(td_item) ||
      !ad_item || !cJSON_IsString(ad_item)) {
    cJSON_Delete(root);
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Missing required peer rule fields");
    return ESP_FAIL;
  }

  peer_rules_load_from_nvs();
  int slot = -1;
  for (size_t i = 0; i < EH_MAX_PEER_RULES; i++) {
    if (s_peer_rules[i].valid &&
        strcmp(s_peer_rules[i].id, id_item->valuestring) == 0) {
      slot = (int)i;
      break;
    }
    if (slot < 0 && !s_peer_rules[i].valid) {
      slot = (int)i;
    }
  }
  if (slot < 0) {
    /* Replace oldest slot 0 if table is full */
    for (size_t i = 1; i < EH_MAX_PEER_RULES; i++) {
      s_peer_rules[i - 1] = s_peer_rules[i];
    }
    slot = EH_MAX_PEER_RULES - 1;
  }

  eh_peer_rule_t *r = &s_peer_rules[slot];
  memset(r, 0, sizeof(*r));
  strncpy(r->id, id_item->valuestring, sizeof(r->id) - 1);
  strncpy(r->trigger_device_id, td_item->valuestring,
          sizeof(r->trigger_device_id) - 1);
  r->trigger_channel = (tc_item && cJSON_IsNumber(tc_item)) ? (uint8_t)tc_item->valueint : 1;
  if (!ts_item || cJSON_IsNull(ts_item)) {
    r->trigger_state = -1;
  } else {
    r->trigger_state = cJSON_IsTrue(ts_item) ? 1 : 0;
  }
  strncpy(r->action_device_id, ad_item->valuestring,
          sizeof(r->action_device_id) - 1);
  if (aip_item && cJSON_IsString(aip_item)) {
    strncpy(r->action_device_ip, aip_item->valuestring,
            sizeof(r->action_device_ip) - 1);
  }
  r->action_channel = (ac_item && cJSON_IsNumber(ac_item)) ? (uint8_t)ac_item->valueint : 1;
  r->is_toggle = (tog_item && cJSON_IsBool(tog_item)) ? cJSON_IsTrue(tog_item) : false;
  r->action_power = (ap_item && cJSON_IsBool(ap_item)) ? cJSON_IsTrue(ap_item) : true;
  if (acmd_item && cJSON_IsString(acmd_item)) {
    if (strcasecmp(acmd_item->valuestring, "TOGGLE") == 0) {
      r->is_toggle = true;
    } else if (strcasecmp(acmd_item->valuestring, "OFF") == 0 ||
               strcasecmp(acmd_item->valuestring, "TURN_OFF") == 0) {
      r->is_toggle = false;
      r->action_power = false;
    } else if (strcasecmp(acmd_item->valuestring, "ON") == 0 ||
               strcasecmp(acmd_item->valuestring, "TURN_ON") == 0) {
      r->is_toggle = false;
      r->action_power = true;
    }
  }
  r->enabled = (en_item && cJSON_IsBool(en_item)) ? cJSON_IsTrue(en_item) : true;
  r->valid = 1;

  cJSON_Delete(root);
  bool saved = peer_rules_save_to_nvs();
  ESP_LOGI(TAG, "Saved P2P peer rule '%s': %s CH%d -> %s (%s) CH%d (%s, en=%d)",
           r->id, r->trigger_device_id, r->trigger_channel,
           r->action_device_id, r->action_device_ip, r->action_channel,
           r->is_toggle ? "TOGGLE" : (r->action_power ? "ON" : "OFF"),
           r->enabled ? 1 : 0);

  size_t active_count = 0;
  for (size_t i = 0; i < EH_MAX_PEER_RULES; i++) {
    if (s_peer_rules[i].valid) active_count++;
  }

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddStringToObject(resp, "status", saved ? "ok" : "error");
  cJSON_AddNumberToObject(resp, "count", (int)active_count);
  const char *resp_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, resp_str);
  free((void *)resp_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

/* DELETE /api/v1/peer-rules?id=... - Remove a persisted P2P peer rule */
static esp_err_t peer_rules_delete_handler(httpd_req_t *req) {
  set_cors_headers(req);
  httpd_resp_set_type(req, "application/json");

  peer_rules_load_from_nvs();
  char rule_id[48] = {0};
  char query[128] = {0};
  if (httpd_req_get_url_query_str(req, query, sizeof(query)) == ESP_OK) {
    httpd_query_key_value(query, "id", rule_id, sizeof(rule_id));
  }

  bool removed = false;
  if (rule_id[0] != '\0') {
    for (size_t i = 0; i < EH_MAX_PEER_RULES; i++) {
      if (s_peer_rules[i].valid &&
          strncmp(s_peer_rules[i].id, rule_id, sizeof(s_peer_rules[i].id) - 1) == 0) {
        memset(&s_peer_rules[i], 0, sizeof(eh_peer_rule_t));
        removed = true;
      }
    }
  } else {
    memset(s_peer_rules, 0, sizeof(s_peer_rules));
    removed = true;
  }

  if (removed) {
    peer_rules_save_to_nvs();
  }

  cJSON *resp = cJSON_CreateObject();
  cJSON_AddStringToObject(resp, "status", "ok");
  cJSON_AddBoolToObject(resp, "deleted", removed);
  const char *resp_str = cJSON_PrintUnformatted(resp);
  httpd_resp_sendstr(req, resp_str);
  free((void *)resp_str);
  cJSON_Delete(resp);
  return ESP_OK;
}

bool local_server_start(void) {
  if (s_server != NULL) {
    ESP_LOGI(TAG, "Local HTTP server already running");
    return true;
  }

  peer_rules_load_from_nvs();
  for (uint8_t i = 0; i < EH_RELAY_CHANNEL_COUNT; i++) {
    s_prev_local_powers[i] = relay_manager_get_power((uint8_t)(i + 1));
  }
  s_prev_local_init = true;

  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;
  config.ctrl_port = 32768;
  config.max_open_sockets = 7;
  config.max_uri_handlers = 32;
  config.recv_wait_timeout = 3;
  config.send_wait_timeout = 3;
  config.stack_size =
      8192; // 8KB stack prevents FreeRTOS stack overflow on JSON/NVS operations
  config.lru_purge_enable = true;

  ESP_LOGI(
      TAG,
      "Starting Local LAN HTTP Server on port %d (stack=%d, max_sockets=%d)...",
      config.server_port, config.stack_size, config.max_open_sockets);
  if (httpd_start(&s_server, &config) != ESP_OK) {
    ESP_LOGE(TAG, "Failed to start Local LAN HTTP Server");
    return false;
  }

  // Register URI Handlers
  httpd_uri_t ping_uri = {
      .uri = "/api/v1/ping",
      .method = HTTP_GET,
      .handler = ping_get_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &ping_uri);

  httpd_uri_t state_uri = {
      .uri = "/api/v1/state",
      .method = HTTP_GET,
      .handler = state_get_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &state_uri);

  httpd_uri_t control_uri = {
      .uri = "/api/v1/control",
      .method = HTTP_POST,
      .handler = control_post_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &control_uri);

  httpd_uri_t reset_uri = {
      .uri = "/api/v1/reset",
      .method = HTTP_POST,
      .handler = reset_post_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &reset_uri);

  httpd_uri_t options_reset_uri = {
      .uri = "/api/v1/reset",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_reset_uri);

  httpd_uri_t options_control_uri = {
      .uri = "/api/v1/control",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_control_uri);

  httpd_uri_t options_state_uri = {
      .uri = "/api/v1/state",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_state_uri);

  /* Edge Routine Engine Endpoints */
  httpd_uri_t routines_get_uri = {
      .uri = "/api/v1/routines",
      .method = HTTP_GET,
      .handler = routines_get_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &routines_get_uri);

  httpd_uri_t routines_post_uri = {
      .uri = "/api/v1/routines",
      .method = HTTP_POST,
      .handler = routines_post_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &routines_post_uri);

  httpd_uri_t routines_delete_uri = {
      .uri = "/api/v1/routines",
      .method = HTTP_DELETE,
      .handler = routines_delete_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &routines_delete_uri);

  httpd_uri_t routines_stop_uri = {
      .uri = "/api/v1/routines/stop",
      .method = HTTP_POST,
      .handler = routines_stop_post_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &routines_stop_uri);

  httpd_uri_t options_routines_uri = {
      .uri = "/api/v1/routines",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_routines_uri);

  httpd_uri_t options_routines_stop_uri = {
      .uri = "/api/v1/routines/stop",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_routines_stop_uri);

  /* Device Settings (Power-on behavior & Child Lock) Endpoints */
  httpd_uri_t settings_get_uri = {
      .uri = "/api/v1/settings",
      .method = HTTP_GET,
      .handler = settings_get_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &settings_get_uri);

  httpd_uri_t settings_power_on_uri = {
      .uri = "/api/v1/settings/power-on",
      .method = HTTP_POST,
      .handler = settings_power_on_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &settings_power_on_uri);

  httpd_uri_t settings_child_lock_uri = {
      .uri = "/api/v1/settings/child-lock",
      .method = HTTP_POST,
      .handler = settings_child_lock_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &settings_child_lock_uri);

  httpd_uri_t options_settings_uri = {
      .uri = "/api/v1/settings",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_settings_uri);

  httpd_uri_t ota_start_uri = {
      .uri = "/api/v1/ota/start",
      .method = HTTP_POST,
      .handler = ota_start_post_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &ota_start_uri);

  httpd_uri_t ota_status_uri = {
      .uri = "/api/v1/ota/status",
      .method = HTTP_GET,
      .handler = ota_status_get_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &ota_status_uri);

  httpd_uri_t options_ota_start_uri = {
      .uri = "/api/v1/ota/start",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_ota_start_uri);

  httpd_uri_t peer_rules_get_uri = {
      .uri = "/api/v1/peer-rules",
      .method = HTTP_GET,
      .handler = peer_rules_get_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &peer_rules_get_uri);

  httpd_uri_t peer_rules_post_uri = {
      .uri = "/api/v1/peer-rules",
      .method = HTTP_POST,
      .handler = peer_rules_post_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &peer_rules_post_uri);

  httpd_uri_t peer_rules_delete_uri = {
      .uri = "/api/v1/peer-rules",
      .method = HTTP_DELETE,
      .handler = peer_rules_delete_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &peer_rules_delete_uri);

  httpd_uri_t options_peer_rules_uri = {
      .uri = "/api/v1/peer-rules",
      .method = HTTP_OPTIONS,
      .handler = options_handler,
      .user_ctx = NULL,
  };
  httpd_register_uri_handler(s_server, &options_peer_rules_uri);

  // Start UDP auto-discovery responder task
  if (s_udp_task == NULL) {
    xTaskCreate(udp_discovery_task, "eh_udp_disc", 4096, NULL, 5, &s_udp_task);
  }

  ESP_LOGI(TAG, "Local LAN HTTP Server started successfully on port 80");
  return true;
}

void local_server_stop(void) {
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

bool local_server_is_running(void) { return s_server != NULL; }
