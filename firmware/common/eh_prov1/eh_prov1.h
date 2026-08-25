#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    EH_PROV1_STATE_FACTORY_NEW = 0,
    EH_PROV1_STATE_COMMISSIONING = 1,
    EH_PROV1_STATE_AUTHENTICATED = 2,
    EH_PROV1_STATE_WIFI_CONFIGURING = 3,
    EH_PROV1_STATE_WIFI_CONNECTING = 4,
    EH_PROV1_STATE_REGISTRATION_PENDING = 5,
    EH_PROV1_STATE_ACTIVE = 6,
    EH_PROV1_STATE_FAILED = 7,
} eh_prov1_state_t;

typedef enum {
    EH_PROV1_MSG_HELLO = 0,
    EH_PROV1_MSG_HELLO_ACK = 1,
    EH_PROV1_MSG_AUTH = 2,
    EH_PROV1_MSG_AUTH_ACK = 3,
    EH_PROV1_MSG_WIFI_CRED = 4,
    EH_PROV1_MSG_WIFI_ACK = 5,
    EH_PROV1_MSG_CONFIRM = 6,
} eh_prov1_msg_type_t;

typedef struct {
    char session_id[37];
    uint8_t app_challenge[32];
    uint8_t device_challenge[32];
    uint8_t session_key[32];
    uint32_t expected_seq;
    bool is_authenticated;
} eh_prov1_session_t;

esp_err_t eh_prov1_init(void);
eh_prov1_state_t eh_prov1_get_state(void);
void eh_prov1_set_state(eh_prov1_state_t state);

/**
 * Encodes canonical transcript into exact byte-level representation.
 */
size_t eh_prov1_encode_transcript(const char *msg_type,
                                   const char *session_id,
                                   const char *device_id,
                                   const uint8_t *app_chal,
                                   const uint8_t *dev_chal,
                                   uint32_t sequence_number,
                                   uint8_t *out_buf,
                                   size_t max_len);

/**
 * Handles incoming raw BLE provisioning frame and populates response buffer.
 */
esp_err_t eh_prov1_handle_message(const uint8_t *in_data, size_t in_len,
                                  uint8_t *out_data, size_t *out_len, size_t max_out_len);

/**
 * Called by device mTLS client after registration success.
 * Sets commissioningSecretConsumed = true and transitions state to ACTIVE.
 */
esp_err_t eh_prov1_on_mtls_registration_success(void);

#ifdef __cplusplus
}
#endif
