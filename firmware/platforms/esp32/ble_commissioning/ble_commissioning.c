#include "ble_commissioning.h"

#include <stdio.h>
#include <string.h>
#include "esp_log.h"
#include "host/ble_hs.h"
#include "host/ble_gatt.h"
#include "host/ble_gap.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "nimble/nimble_npl.h"
#include "os/os_mbuf.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "eh_prov1.h"
#include "factory_identity_v2.h"

static const char *TAG = "ble_commissioning";
static uint8_t s_own_addr_type = 0;
static uint16_t s_conn_handle = BLE_HS_CONN_HANDLE_NONE;

/* Service 1 (Device Info & Telemetry): handles and subscription flags */
static uint16_t s_telemetry_handle;
static uint16_t s_status_handle;
static uint16_t s_product_info_handle;
static bool s_telemetry_subscribed = false;
static bool s_status_subscribed = false;

/* Service 2 (EH-PROV/1 Secure Commissioning): handles and subscription flags */
static uint16_t s_rx_handle;
static uint16_t s_tx_handle;
static bool s_tx_subscribed = false;

static bool s_initialized = false;

#define MAX_TX_QUEUE_ITEMS 16
#define MAX_TX_FRAME_LEN 32

typedef struct {
    uint16_t conn_handle;
    uint16_t attr_handle;
    uint8_t data[MAX_TX_FRAME_LEN];
    size_t len;
    uint8_t msg_type;
    uint8_t frame_index;
    uint8_t total_frames;
} prov_tx_item_t;

/* Bounded owned TX queue for NimBLE host-context dispatch */
static prov_tx_item_t s_tx_queue[MAX_TX_QUEUE_ITEMS];
static size_t s_tx_head = 0;
static size_t s_tx_tail = 0;
static size_t s_tx_count = 0;
static struct ble_npl_event s_tx_event;

/* Static BSS buffers to prevent stack pressure on the 4KB ble_host_task */
static uint8_t s_rx_in_buf[256];
static uint8_t s_msg_buf[512];
static uint8_t s_out_buf[256];

/**
 * Authoritative NimBLE host execution context for BLE notifications.
 * Executes on ble_host_task from nimble_port_run() event queue.
 * Processes exactly one transport frame per host scheduling turn.
 */
static void prov_tx_event_cb(struct ble_npl_event *ev)
{
    (void)ev;
    if (s_tx_count == 0) {
        return;
    }

    prov_tx_item_t item = s_tx_queue[s_tx_head];
    s_tx_head = (s_tx_head + 1) % MAX_TX_QUEUE_ITEMS;
    s_tx_count--;

    if (item.conn_handle == BLE_HS_CONN_HANDLE_NONE ||
        item.conn_handle != s_conn_handle ||
        !s_tx_subscribed) {
        ESP_LOGW(TAG, "BLE_TX_DROPPED_NOT_SUBSCRIBED (conn=%d, sub=%d)", item.conn_handle, s_tx_subscribed);
        return;
    }

    struct os_mbuf *tx_om = ble_hs_mbuf_from_flat(item.data, item.len);
    if (!tx_om) {
        ESP_LOGE(TAG, "Failed to allocate os_mbuf for BLE TX notification");
        return;
    }

    int rc = ble_gatts_notify_custom(item.conn_handle, item.attr_handle, tx_om);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gatts_notify_custom failed: rc=%d", rc);
    } else {
        if (item.msg_type == EH_PROV1_MSG_HELLO_ACK) {
            ESP_LOGI(TAG, "PROV_HELLO_ACK_SENT frame=%u", (unsigned)item.frame_index);
        } else if (item.msg_type == EH_PROV1_MSG_AUTH_ACK) {
            ESP_LOGI(TAG, "PROV_AUTH_ACK_SENT frame=%u", (unsigned)item.frame_index);
        } else if (item.msg_type == EH_PROV1_MSG_WIFI_ACK) {
            ESP_LOGI(TAG, "PROV_WIFI_ACK_SENT frame=%u", (unsigned)item.frame_index);
        }
    }

    /* Schedule the next frame in host event loop (sequential dispatch) */
    if (s_tx_count > 0 && s_tx_subscribed && s_conn_handle != BLE_HS_CONN_HANDLE_NONE) {
        ble_npl_eventq_put(nimble_port_get_dflt_eventq(), &s_tx_event);
    }
}

/* Proprietary EH Home UUID namespace:
 * - 0x6101: Primary Service 1 (Device Info & Telemetry - Used by Flutter Home Controller)
 * - 0x6103: Characteristic (Telemetry - READ | NOTIFY)
 * - 0x6104: Characteristic (Status - READ | NOTIFY)
 * - 0x6105: Characteristic (Product Info - READ)
 * - 0x6102: Primary Service 2 (EH-PROV/1 Secure Commissioning - Used by Onboarding Crypto Handshake)
 * - 0x6110: Characteristic (RX - WRITE)
 * - 0x6111: Characteristic (TX - NOTIFY)
 */

/* Service 1: Device Info & Telemetry (a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6101) */
static const ble_uuid128_t s_device_info_service_uuid = BLE_UUID128_INIT(
    0x01, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_telemetry_uuid = BLE_UUID128_INIT(
    0x03, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_status_uuid = BLE_UUID128_INIT(
    0x04, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_product_info_uuid = BLE_UUID128_INIT(
    0x05, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

/* Service 2: EH-PROV/1 Secure Commissioning (a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6102) */
static const ble_uuid128_t s_prov_service_uuid = BLE_UUID128_INIT(
    0x02, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_prov_rx_uuid = BLE_UUID128_INIT(
    0x10, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_prov_tx_uuid = BLE_UUID128_INIT(
    0x11, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static int append_read_slice(struct ble_gatt_access_ctxt *ctxt,
                             const char *payload, size_t length)
{
    if (ctxt->offset > length) {
        ESP_LOGW(TAG, "GATT read offset error: offset=%u > length=%u", (unsigned)ctxt->offset, (unsigned)length);
        return BLE_ATT_ERR_INVALID_OFFSET;
    }
    if (ctxt->offset == length) {
        ESP_LOGD(TAG, "GATT read EOF: offset=%u == length=%u", (unsigned)ctxt->offset, (unsigned)length);
        return 0;
    }
    size_t chunk_len = length - ctxt->offset;
    ESP_LOGI(TAG, "GATT_6105_READ_OFFSET offset=%u total=%u chunk=%u",
             (unsigned)ctxt->offset, (unsigned)length, (unsigned)chunk_len);
    int rc = os_mbuf_append(ctxt->om, payload + ctxt->offset, chunk_len);
    return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static int gatt_svr_access_device_info(uint16_t conn_handle, uint16_t attr_handle,
                                       struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)arg;

    if (ctxt->op != BLE_GATT_ACCESS_OP_READ_CHR) return BLE_ATT_ERR_READ_NOT_PERMITTED;

    const factory_identity_v2_t *id = factory_identity_v2_get();
    char payload[256];
    int len = 0;

    if (attr_handle == s_product_info_handle) {
        /* Encodes JSON public product metadata matching Flutter BleConnectionRepository expectations */
        len = snprintf(payload, sizeof(payload),
                       "{\"product\":\"EH Smart Switch 3X\",\"p\":\"EH Smart Switch 3X\","
                       "\"deviceId\":\"%s\",\"serialNumber\":\"%s\",\"firmwareVersion\":\"1.0.0\","
                       "\"variant\":\"eh-smart-switch-3x\"}",
                       id ? id->device_id : "UNKNOWN",
                       id ? id->serial_number : "UNKNOWN");
        ESP_LOGI(TAG, "GATT_6105_READ_START len=%d offset=%d", len, ctxt->offset);
    } else if (attr_handle == s_status_handle) {
        eh_prov1_state_t prov_st = eh_prov1_get_state();
        const char *st_name = (prov_st == EH_PROV1_STATE_ACTIVE)
                                  ? "ACTIVE"
                                  : (prov_st == EH_PROV1_STATE_WIFI_CONNECTING
                                         ? "WIFI_CONNECTING"
                                         : "BLE_COMMISSIONING");
        bool is_wifi_active = (prov_st == EH_PROV1_STATE_ACTIVE);
        len = snprintf(payload, sizeof(payload),
                       "{\"state\":\"%s\",\"wifi\":%s,\"mqtt\":false,\"relays\":[false,false,false]}",
                       st_name, is_wifi_active ? "true" : "false");
    } else if (attr_handle == s_telemetry_handle) {
        len = snprintf(payload, sizeof(payload),
                       "{\"v\":230.0,\"i\":0.0,\"p\":0.0,\"e\":0.0}");
    }

    if (len > 0) {
        int res = append_read_slice(ctxt, payload, (size_t)len);
        if (res == 0 && attr_handle == s_product_info_handle) {
            ESP_LOGI(TAG, "GATT_6105_READ_OK");
        }
        return res;
    }
    return BLE_ATT_ERR_INSUFFICIENT_RES;
}

static int gatt_access_cb(uint16_t conn_handle, uint16_t attr_handle,
                           struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)arg;

    if (attr_handle == s_rx_handle && ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
        uint16_t in_len = OS_MBUF_PKTLEN(ctxt->om);
        if (in_len > sizeof(s_rx_in_buf)) return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;

        os_mbuf_copydata(ctxt->om, 0, in_len, s_rx_in_buf);

        size_t msg_len = sizeof(s_msg_buf);
        bool is_complete = false;

        esp_err_t frame_err = eh_prov1_process_frame(s_rx_in_buf, in_len, s_msg_buf, &msg_len, &is_complete);
        if (frame_err != ESP_OK) {
            ESP_LOGE(TAG, "eh_prov1_process_frame error: %d", frame_err);
            return BLE_ATT_ERR_UNLIKELY;
        }

        if (!is_complete) {
            // Transport frame accepted. Return 0 (success) immediately.
            return 0;
        }

        // Full message reassembled -> execute protocol handler
        size_t out_len = 0;
        esp_err_t err = eh_prov1_handle_message(s_msg_buf, msg_len, s_out_buf, &out_len, sizeof(s_out_buf));

        if (err == ESP_OK && out_len > 0) {
            if (!s_tx_subscribed || s_conn_handle == BLE_HS_CONN_HANDLE_NONE) {
                ESP_LOGW(TAG, "BLE_TX_DROPPED_NOT_SUBSCRIBED");
                return 0;
            }

            const size_t max_chunk_len = 16;
            size_t total_frames = (out_len + max_chunk_len - 1) / max_chunk_len;
            if (total_frames == 0) total_frames = 1;

            for (uint8_t f = 0; f < total_frames; f++) {
                if (s_tx_count >= MAX_TX_QUEUE_ITEMS) {
                    ESP_LOGE(TAG, "BLE_TX_QUEUE_FULL dropped frame %u of %u", f, (unsigned)total_frames);
                    break;
                }
                uint8_t frame_buf[32];
                size_t frame_len = eh_prov1_fragment_payload(s_out_buf, out_len, f, frame_buf, sizeof(frame_buf));
                if (frame_len > 0) {
                    s_tx_queue[s_tx_tail].conn_handle = s_conn_handle;
                    s_tx_queue[s_tx_tail].attr_handle = s_tx_handle;
                    memcpy(s_tx_queue[s_tx_tail].data, frame_buf, frame_len);
                    s_tx_queue[s_tx_tail].len = frame_len;
                    s_tx_queue[s_tx_tail].msg_type = s_out_buf[0];
                    s_tx_queue[s_tx_tail].frame_index = f;
                    s_tx_queue[s_tx_tail].total_frames = (uint8_t)total_frames;
                    s_tx_tail = (s_tx_tail + 1) % MAX_TX_QUEUE_ITEMS;
                    s_tx_count++;
                }
            }

            if (s_out_buf[0] == EH_PROV1_MSG_HELLO_ACK) {
                ESP_LOGI(TAG, "PROV_HELLO_ACK_QUEUED frames=%u", (unsigned)total_frames);
            } else if (s_out_buf[0] == EH_PROV1_MSG_AUTH_ACK) {
                ESP_LOGI(TAG, "PROV_AUTH_ACK_QUEUED frames=%u", (unsigned)total_frames);
            } else if (s_out_buf[0] == EH_PROV1_MSG_WIFI_ACK) {
                ESP_LOGI(TAG, "PROV_WIFI_ACK_QUEUED frames=%u", (unsigned)total_frames);
            }

            /* Schedule host-context notification event on NimBLE default event queue */
            ble_npl_eventq_put(nimble_port_get_dflt_eventq(), &s_tx_event);
        }
        return err == ESP_OK ? 0 : BLE_ATT_ERR_UNLIKELY;
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def s_prov_gatt_svcs[] = {
    {
        /* Service 1: Device Info & Telemetry (a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6101) */
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &s_device_info_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                /* Telemetry: Read & Notify */
                .uuid = &s_telemetry_uuid.u,
                .access_cb = gatt_svr_access_device_info,
                .val_handle = &s_telemetry_handle,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
            },
            {
                /* Status: Read & Notify */
                .uuid = &s_status_uuid.u,
                .access_cb = gatt_svr_access_device_info,
                .val_handle = &s_status_handle,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
            },
            {
                /* Product Info: Read (Queried by Flutter BleConnectionRepository) */
                .uuid = &s_product_info_uuid.u,
                .access_cb = gatt_svr_access_device_info,
                .val_handle = &s_product_info_handle,
                .flags = BLE_GATT_CHR_F_READ,
            },
            {0},
        },
    },
    {
        /* Service 2: EH-PROV/1 Secure Commissioning (a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6102) */
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &s_prov_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                /* Write-only RX characteristic: credentials and proofs cannot be read back */
                .uuid = &s_prov_rx_uuid.u,
                .access_cb = gatt_access_cb,
                .val_handle = &s_rx_handle,
                .flags = BLE_GATT_CHR_F_WRITE,
            },
            {
                /* Notify-only TX characteristic: pushes server responses */
                .uuid = &s_prov_tx_uuid.u,
                .access_cb = gatt_access_cb,
                .val_handle = &s_tx_handle,
                .flags = BLE_GATT_CHR_F_NOTIFY,
            },
            {0},
        },
    },
    {0},
};

static int gap_event_cb(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            s_conn_handle = event->connect.conn_handle;
            ESP_LOGI(TAG, "Flutter connected for BLE services (conn_handle=%d)", s_conn_handle);
        } else {
            ESP_LOGW(TAG, "BLE connection failed: status=%d", event->connect.status);
            ble_commissioning_start_advertising();
        }
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(TAG, "BLE disconnected (reason=%d), restarting advertising", event->disconnect.reason);
        s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
        s_tx_subscribed = false;
        s_telemetry_subscribed = false;
        s_status_subscribed = false;
        s_tx_head = 0;
        s_tx_tail = 0;
        s_tx_count = 0;
        eh_prov1_reset_framing();
        ble_commissioning_start_advertising();
        return 0;
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == s_tx_handle) {
            s_tx_subscribed = event->subscribe.cur_notify;
            ESP_LOGI(TAG, "BLE TX (EH-PROV/1) subscription: %s", s_tx_subscribed ? "SUBSCRIBED" : "UNSUBSCRIBED");
        } else if (event->subscribe.attr_handle == s_telemetry_handle) {
            s_telemetry_subscribed = event->subscribe.cur_notify;
            ESP_LOGI(TAG, "BLE Telemetry subscription: %s", s_telemetry_subscribed ? "SUBSCRIBED" : "UNSUBSCRIBED");
        } else if (event->subscribe.attr_handle == s_status_handle) {
            s_status_subscribed = event->subscribe.cur_notify;
            ESP_LOGI(TAG, "BLE Status subscription: %s", s_status_subscribed ? "SUBSCRIBED" : "UNSUBSCRIBED");
        }
        return 0;
    default:
        return 0;
    }
}

void ble_commissioning_start_advertising(void)
{
    const factory_identity_v2_t *id = factory_identity_v2_get();
    if (!id) {
        ESP_LOGE(TAG, "Factory identity unavailable for BLE advertising");
        return;
    }

    if (id->commissioning_secret_consumed && eh_prov1_get_state() == EH_PROV1_STATE_ACTIVE) {
        ESP_LOGI(TAG, "Commissioning secret consumed & device is ACTIVE. Skipping BLE advertising.");
        return;
    }

    /* Primary advertisement packet: Flags and Device Name */
    struct ble_hs_adv_fields adv = {0};
    adv.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    adv.name = (uint8_t *)id->serial_number;
    adv.name_len = (uint8_t)strlen(id->serial_number);
    adv.name_is_complete = 1;

    int rc = ble_gap_adv_set_fields(&adv);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to set advertising fields: rc=%d", rc);
        return;
    }

    /* Scan Response packet: Advertises Primary Service UUID ...6101 for Flutter Discovery */
    struct ble_hs_adv_fields scan_rsp = {0};
    scan_rsp.uuids128 = (ble_uuid128_t *)&s_device_info_service_uuid;
    scan_rsp.num_uuids128 = 1;
    scan_rsp.uuids128_is_complete = 1;

    rc = ble_gap_adv_rsp_set_fields(&scan_rsp);
    if (rc != 0) {
        ESP_LOGW(TAG, "Failed to set scan response fields: rc=%d", rc);
    }

    struct ble_gap_adv_params params = {0};
    params.conn_mode = BLE_GAP_CONN_MODE_UND;
    params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER, &params, gap_event_cb, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to start advertising: rc=%d", rc);
        return;
    }
    ESP_LOGI(TAG, "Advertising BLE Services (6101 & 6102) for device %s", id->serial_number);
}

static void ble_on_sync(void)
{
    int rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to infer own address type: rc=%d", rc);
        return;
    }
    ESP_LOGI(TAG, "NimBLE host synced, address type=%d", s_own_addr_type);
    ble_commissioning_start_advertising();
}

static void ble_on_reset(int reason)
{
    ESP_LOGE(TAG, "NimBLE host reset: reason=%d", reason);
}

static void ble_host_task(void *param)
{
    (void)param;
    ESP_LOGI(TAG, "NimBLE Host Task Started");
    nimble_port_run();
    nimble_port_freertos_deinit();
}

esp_err_t ble_commissioning_init(void)
{
    if (s_initialized) {
        ESP_LOGI(TAG, "BLE commissioning already initialized");
        return ESP_OK;
    }

    eh_prov1_init();

    esp_err_t ret = nimble_port_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize NimBLE port: %s", esp_err_to_name(ret));
        return ret;
    }

    ble_npl_event_init(&s_tx_event, prov_tx_event_cb, NULL);

    const factory_identity_v2_t *id = factory_identity_v2_get();
    const char *device_name = (id && strlen(id->serial_number) > 0) ? id->serial_number : "EH-DEVICE";

    ble_svc_gap_init();
    ble_svc_gatt_init();

    int rc = ble_svc_gap_device_name_set(device_name);
    if (rc != 0) {
        ESP_LOGW(TAG, "Failed to set GAP device name: rc=%d", rc);
    }

    ble_hs_cfg.sync_cb = ble_on_sync;
    ble_hs_cfg.reset_cb = ble_on_reset;

    rc = ble_gatts_count_cfg(s_prov_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to count GATT config: rc=%d", rc);
        return ESP_FAIL;
    }

    rc = ble_gatts_add_svcs(s_prov_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to add GATT services: rc=%d", rc);
        return ESP_FAIL;
    }

    nimble_port_freertos_init(ble_host_task);
    s_initialized = true;
    ESP_LOGI(TAG, "BLE Services 6101 (Info/Telemetry) & 6102 (EH-PROV/1) initialized successfully (name: %s)", device_name);
    return ESP_OK;
}
