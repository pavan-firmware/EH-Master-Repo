#include "ble_server.h"

#include <assert.h>
#include <stdbool.h>
#include <string.h>

#include "esp_check.h"
#include "esp_log.h"
#include "host/ble_att.h"
#include "host/ble_gatt.h"
#include "host/ble_gap.h"
#include "host/ble_hs.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "os/os_mbuf.h"
#include "services/gap/ble_svc_gap.h"

#include "node_identity.h"
#include "node_protocol.h"
#include "product_profile.h"

static const char *TAG = "ble_server";
static uint8_t s_own_addr_type;
static uint16_t s_connection_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_telemetry_handle;
static uint16_t s_status_handle;
static uint16_t s_product_info_handle;
static bool s_telemetry_subscribed;
static bool s_status_subscribed;

/* Proprietary Smart Home UUID namespace, not Nordic UART UUIDs. */
static const ble_uuid128_t s_service_uuid = BLE_UUID128_INIT(
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

static int append_read_slice(struct ble_gatt_access_ctxt *ctxt,
                             const char *payload, size_t length)
{
    if (ctxt->offset >= length) return 0;
    return os_mbuf_append(ctxt->om, payload + ctxt->offset, length - ctxt->offset) == 0
        ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static int read_status_cb(uint16_t conn_handle, uint16_t attr_handle,
                          struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)arg;
    if (ctxt->op != BLE_GATT_ACCESS_OP_READ_CHR) return BLE_ATT_ERR_READ_NOT_PERMITTED;

    char payload[192];
    size_t length;
    if (attr_handle == s_product_info_handle) {
        length = product_profile_make_public_json(payload, sizeof(payload));
    } else if (attr_handle == s_status_handle) {
        length = node_protocol_make_provisioning_status(payload, sizeof(payload));
    } else {
        length = node_protocol_make_telemetry(payload, sizeof(payload));
    }
    return length > 0 ? append_read_slice(ctxt, payload, length)
                      : BLE_ATT_ERR_INSUFFICIENT_RES;
}

static const struct ble_gatt_svc_def s_gatt_services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &s_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &s_telemetry_uuid.u,
                .access_cb = read_status_cb,
                .val_handle = &s_telemetry_handle,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
            },
            {
                .uuid = &s_status_uuid.u,
                .access_cb = read_status_cb,
                .val_handle = &s_status_handle,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
            },
            {
                .uuid = &s_product_info_uuid.u,
                .access_cb = read_status_cb,
                .val_handle = &s_product_info_handle,
                .flags = BLE_GATT_CHR_F_READ,
            },
            {0},
        },
    },
    {0},
};

static int gap_event(struct ble_gap_event *event, void *arg);

static void start_advertising(void)
{
    const char *name = node_identity_ble_name();
    struct ble_hs_adv_fields primary = {0};
    primary.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    primary.name = (uint8_t *)name;
    primary.name_len = strlen(name);
    primary.name_is_complete = 1;

    int rc = ble_gap_adv_set_fields(&primary);
    if (rc != 0) {
        ESP_LOGE(TAG, "Primary advertisement failed: %d", rc);
        return;
    }

    struct ble_hs_adv_fields scan_response = {0};
    scan_response.uuids128 = (ble_uuid128_t *)&s_service_uuid;
    scan_response.num_uuids128 = 1;
    scan_response.uuids128_is_complete = 1;
    rc = ble_gap_adv_rsp_set_fields(&scan_response);
    if (rc != 0) {
        ESP_LOGE(TAG, "Scan response failed: %d", rc);
        return;
    }

    struct ble_gap_adv_params params = {0};
    params.conn_mode = BLE_GAP_CONN_MODE_UND;
    params.disc_mode = BLE_GAP_DISC_MODE_GEN;
    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER, &params,
                           gap_event, NULL);
    if (rc == 0) ESP_LOGI(TAG, "%s is advertising for Flutter", name);
    else ESP_LOGE(TAG, "Advertising failed: %d", rc);
}

static int gap_event(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            s_connection_handle = event->connect.conn_handle;
            ESP_LOGI(TAG, "Flutter connected");
        } else start_advertising();
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        s_connection_handle = BLE_HS_CONN_HANDLE_NONE;
        s_telemetry_subscribed = false;
        s_status_subscribed = false;
        start_advertising();
        return 0;
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == s_telemetry_handle)
            s_telemetry_subscribed = event->subscribe.cur_notify;
        if (event->subscribe.attr_handle == s_status_handle)
            s_status_subscribed = event->subscribe.cur_notify;
        return 0;
    default:
        return 0;
    }
}

static void on_sync(void)
{
    ESP_ERROR_CHECK(ble_hs_id_infer_auto(0, &s_own_addr_type));
    start_advertising();
}

static void host_task(void *param)
{
    (void)param;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

esp_err_t ble_server_init(void)
{
    ESP_RETURN_ON_ERROR(nimble_port_init(), TAG, "NimBLE init failed");
    ble_svc_gap_device_name_set(node_identity_ble_name());
    ble_hs_cfg.sync_cb = on_sync;
    assert(ble_gatts_count_cfg(s_gatt_services) == 0);
    assert(ble_gatts_add_svcs(s_gatt_services) == 0);
    nimble_port_freertos_init(host_task);
    return ESP_OK;
}

void ble_server_publish_state(void)
{
    if (s_connection_handle == BLE_HS_CONN_HANDLE_NONE) return;
    if (s_telemetry_subscribed) ble_gatts_chr_updated(s_telemetry_handle);
    if (s_status_subscribed) ble_gatts_chr_updated(s_status_handle);
}
