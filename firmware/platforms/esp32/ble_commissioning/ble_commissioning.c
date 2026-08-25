#include "ble_commissioning.h"

#include <string.h>
#include "esp_log.h"
#include "host/ble_hs.h"
#include "host/ble_gatt.h"
#include "host/ble_gap.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "services/gap/ble_svc_gap.h"

#include "eh_prov1.h"
#include "factory_identity_v2.h"

static const char *TAG = "ble_commissioning";
static uint8_t s_own_addr_type;
static uint16_t s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_rx_handle;
static uint16_t s_tx_handle;
static bool s_tx_subscribed;

/* Proprietary EH-PROV/1 Service and Characteristic UUIDs */
static const ble_uuid128_t s_prov_service_uuid = BLE_UUID128_INIT(
    0x02, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_prov_rx_uuid = BLE_UUID128_INIT(
    0x10, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static const ble_uuid128_t s_prov_tx_uuid = BLE_UUID128_INIT(
    0x11, 0x61, 0x3b, 0x9f, 0x7a, 0x5c, 0x19, 0x8e,
    0x60, 0x4c, 0x47, 0x2b, 0xf0, 0xe1, 0xd4, 0xa8);

static int gatt_access_cb(uint16_t conn_handle, uint16_t attr_handle,
                           struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)arg;

    if (attr_handle == s_rx_handle && ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
        uint16_t in_len = OS_MBUF_PKTLEN(ctxt->om);
        uint8_t in_buf[256];
        if (in_len > sizeof(in_buf)) return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;

        os_mbuf_copydata(ctxt->om, 0, in_len, in_buf);

        uint8_t out_buf[256];
        size_t out_len = 0;
        esp_err_t err = eh_prov1_handle_message(in_buf, in_len, out_buf, &out_len, sizeof(out_buf));

        if (err == ESP_OK && out_len > 0 && s_tx_subscribed) {
            struct os_mbuf *tx_om = ble_hs_mbuf_from_flat(out_buf, out_len);
            if (tx_om) {
                ble_gatts_notify_custom(s_conn_handle, s_tx_handle, tx_om);
            }
        }
        return err == ESP_OK ? 0 : BLE_ATT_ERR_UNLIKELY;
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def s_prov_gatt_svcs[] = {
    {
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
            ESP_LOGI(TAG, "Flutter connected for BLE commissioning");
        } else {
            ble_commissioning_start_advertising();
        }
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
        s_tx_subscribed = false;
        ble_commissioning_start_advertising();
        return 0;
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == s_tx_handle) {
            s_tx_subscribed = event->subscribe.cur_notify;
        }
        return 0;
    default:
        return 0;
    }
}

void ble_commissioning_start_advertising(void)
{
    const factory_identity_v2_t *id = factory_identity_v2_get();
    if (id->commissioning_secret_consumed && eh_prov1_get_state() == EH_PROV1_STATE_ACTIVE) {
        ESP_LOGI(TAG, "Commissioning secret consumed & device is ACTIVE. Skipping BLE advertising.");
        return;
    }

    struct ble_hs_adv_fields adv = {0};
    adv.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    adv.name = (uint8_t *)id->serial_number;
    adv.name_len = strlen(id->serial_number);
    adv.name_is_complete = 1;

    ble_gap_adv_set_fields(&adv);

    struct ble_gap_adv_params params = {0};
    params.conn_mode = BLE_GAP_CONN_MODE_UND;
    params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER, &params, gap_event_cb, NULL);
    ESP_LOGI(TAG, "Advertising BLE Commissioning Service for device %s", id->serial_number);
}

esp_err_t ble_commissioning_init(void)
{
    factory_identity_v2_init();
    eh_prov1_init();

    nimble_port_init();
    ble_svc_gap_device_name_set(factory_identity_v2_get()->serial_number);
    ble_gatts_add_svcs(s_prov_gatt_svcs);
    return ESP_OK;
}
