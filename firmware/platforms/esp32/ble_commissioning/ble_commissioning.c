#include "ble_commissioning.h"

#include <stdio.h>
#include <string.h>
#include "esp_log.h"
#include "host/ble_hs.h"
#include "host/ble_gatt.h"
#include "host/ble_gap.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
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
static uint16_t s_rx_handle_s1;
static uint16_t s_tx_handle_s1;
static uint16_t s_active_tx_handle = 0;
static bool s_tx_subscribed = false;

static bool s_initialized = false;

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
    if (ctxt->offset >= length) return 0;
    return os_mbuf_append(ctxt->om, payload + ctxt->offset, length - ctxt->offset) == 0
        ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
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
    } else if (attr_handle == s_status_handle) {
        len = snprintf(payload, sizeof(payload),
                       "{\"state\":\"BLE_COMMISSIONING\",\"wifi\":false,\"mqtt\":false,\"relays\":[false,false,false]}");
    } else if (attr_handle == s_telemetry_handle) {
        len = snprintf(payload, sizeof(payload),
                       "{\"v\":230.0,\"i\":0.0,\"p\":0.0,\"e\":0.0}");
    }

    if (len > 0) {
        return append_read_slice(ctxt, payload, (size_t)len);
    }
    return BLE_ATT_ERR_INSUFFICIENT_RES;
}

static uint8_t s_rx_reassembly_buf[512];
static size_t s_rx_reassembly_len = 0;
static uint8_t s_rx_expected_frames = 0;
static uint8_t s_rx_received_frames = 0;

static void notify_tx_payload(const uint8_t *payload, size_t len)
{
    if (!s_tx_subscribed || s_conn_handle == BLE_HS_CONN_HANDLE_NONE) {
        ESP_LOGW(TAG, "Cannot notify TX: client not subscribed (s_tx_subscribed=%d)", s_tx_subscribed);
        return;
    }

    if (len <= 20) {
        /* Single frame notification */
        uint8_t frame[24];
        frame[0] = 0;
        frame[1] = 1;
        memcpy(frame + 2, payload, len);
        struct os_mbuf *tx_om = ble_hs_mbuf_from_flat(frame, len + 2);
        if (tx_om) {
            uint16_t handle = s_active_tx_handle != 0 ? s_active_tx_handle : (s_tx_handle != 0 ? s_tx_handle : s_tx_handle_s1);
            ble_gatts_notify_custom(s_conn_handle, handle, tx_om);
        }
        return;
    }

    /* Multi-frame fragmented notification: 16 bytes payload per frame */
    size_t chunk_size = 16;
    uint8_t total_frames = (len + chunk_size - 1) / chunk_size;
    for (uint8_t i = 0; i < total_frames; i++) {
        size_t start = i * chunk_size;
        size_t chunk_len = (start + chunk_size < len) ? chunk_size : (len - start);
        uint8_t frame[20];
        frame[0] = i;
        frame[1] = total_frames;
        memcpy(frame + 2, payload + start, chunk_len);
        struct os_mbuf *tx_om = ble_hs_mbuf_from_flat(frame, chunk_len + 2);
        if (tx_om) {
            uint16_t handle = s_active_tx_handle != 0 ? s_active_tx_handle : (s_tx_handle != 0 ? s_tx_handle : s_tx_handle_s1);
            ble_gatts_notify_custom(s_conn_handle, handle, tx_om);
        }
    }
}

static int gatt_access_cb(uint16_t conn_handle, uint16_t attr_handle,
                           struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)arg;

    if ((attr_handle == s_rx_handle || attr_handle == s_rx_handle_s1) && ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
        uint16_t in_len = OS_MBUF_PKTLEN(ctxt->om);
        uint8_t in_buf[256];
        if (in_len > sizeof(in_buf)) return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;

        os_mbuf_copydata(ctxt->om, 0, in_len, in_buf);

        const uint8_t *msg_ptr = in_buf;
        size_t msg_len = in_len;

        /* Check if incoming write has 2-byte fragmentation header [frame_idx, total_frames, chunk...] */
        if (in_len >= 2 && in_buf[1] > 1) {
            uint8_t frame_idx = in_buf[0];
            uint8_t total_frames = in_buf[1];

            if (frame_idx == 0) {
                s_rx_reassembly_len = 0;
                s_rx_expected_frames = total_frames;
                s_rx_received_frames = 0;
            }

            if (total_frames != s_rx_expected_frames || frame_idx != s_rx_received_frames) {
                ESP_LOGE(TAG, "BLE frame ordering mismatch: expected frame %d of %d, got %d of %d",
                         s_rx_received_frames, s_rx_expected_frames, frame_idx, total_frames);
                s_rx_reassembly_len = 0;
                s_rx_expected_frames = 0;
                s_rx_received_frames = 0;
                return BLE_ATT_ERR_UNLIKELY;
            }

            size_t chunk_len = in_len - 2;
            if (s_rx_reassembly_len + chunk_len > sizeof(s_rx_reassembly_buf)) {
                return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
            }

            memcpy(s_rx_reassembly_buf + s_rx_reassembly_len, in_buf + 2, chunk_len);
            s_rx_reassembly_len += chunk_len;
            s_rx_received_frames++;

            if (s_rx_received_frames < s_rx_expected_frames) {
                /* Intermediate frame received successfully */
                return 0;
            }

            /* All frames received! Reassembled message is ready */
            msg_ptr = s_rx_reassembly_buf;
            msg_len = s_rx_reassembly_len;
            s_rx_reassembly_len = 0;
            s_rx_expected_frames = 0;
            s_rx_received_frames = 0;
        } else if (in_len >= 2 && in_buf[0] == 0 && in_buf[1] == 1) {
            /* Single-frame packet with 2-byte header */
            msg_ptr = in_buf + 2;
            msg_len = in_len - 2;
        }

        uint8_t out_buf[256];
        size_t out_len = 0;
        ESP_LOGI(TAG, "Processing EH-PROV/1 message (type=%d, len=%zu)", msg_ptr[0], msg_len);
        esp_err_t err = eh_prov1_handle_message(msg_ptr, msg_len, out_buf, &out_len, sizeof(out_buf));

        if (err == ESP_OK && out_len > 0) {
            ESP_LOGI(TAG, "EH-PROV/1 response ready (type=%d, len=%zu), sending notifications", out_buf[0], out_len);
            notify_tx_payload(out_buf, out_len);
        } else if (err != ESP_OK) {
            ESP_LOGE(TAG, "eh_prov1_handle_message failed: %s (err=%d)", esp_err_to_name(err), err);
        }
        return err == ESP_OK ? 0 : BLE_ATT_ERR_UNLIKELY;
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def s_prov_gatt_svcs[] = {
    {
        /* Service 1: Device Info & Telemetry + Commissioning (a8d4e1f0-2b47-4c60-8e19-5c7a9f3b6101) */
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
            {
                /* Commissioning RX */
                .uuid = &s_prov_rx_uuid.u,
                .access_cb = gatt_access_cb,
                .val_handle = &s_rx_handle_s1,
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
            },
            {
                /* Commissioning TX */
                .uuid = &s_prov_tx_uuid.u,
                .access_cb = gatt_access_cb,
                .val_handle = &s_tx_handle_s1,
                .flags = BLE_GATT_CHR_F_NOTIFY,
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
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
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
            s_active_tx_handle = 0;
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
        s_active_tx_handle = 0;
        s_telemetry_subscribed = false;
        s_status_subscribed = false;
        ble_commissioning_start_advertising();
        return 0;
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == s_tx_handle || event->subscribe.attr_handle == s_tx_handle_s1) {
            s_tx_subscribed = event->subscribe.cur_notify;
            s_active_tx_handle = event->subscribe.attr_handle;
            ESP_LOGI(TAG, "BLE TX (EH-PROV/1) subscription on handle %d: %s", s_active_tx_handle, s_tx_subscribed ? "SUBSCRIBED" : "UNSUBSCRIBED");
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
