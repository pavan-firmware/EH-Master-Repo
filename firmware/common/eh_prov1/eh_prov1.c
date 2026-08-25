#include "eh_prov1.h"

#include <stdio.h>
#include <string.h>
#include <arpa/inet.h> /* for htonl */
#include "esp_err.h"
#include "esp_log.h"
#include "esp_random.h"
#include "mbedtls/gcm.h"
#include "mbedtls/hkdf.h"
#include "mbedtls/md.h"

#include "factory_identity_v2.h"

static const char *TAG = "eh_prov1";
static eh_prov1_state_t s_state = EH_PROV1_STATE_FACTORY_NEW;
static eh_prov1_session_t s_session;
static eh_prov1_framing_t s_framing;

static int constant_time_memcmp(const void *a, const void *b, size_t size)
{
    const uint8_t *p1 = (const uint8_t *)a;
    const uint8_t *p2 = (const uint8_t *)b;
    uint8_t result = 0;
    for (size_t i = 0; i < size; i++) {
        result |= p1[i] ^ p2[i];
    }
    return result;
}

size_t eh_prov1_encode_transcript(const char *msg_type,
                                   const char *session_id,
                                   const char *device_id,
                                   const uint8_t *app_chal,
                                   const uint8_t *dev_chal,
                                   uint32_t sequence_number,
                                   uint8_t *out_buf,
                                   size_t max_len)
{
    const char *proto = "EH-PROV/1";
    uint8_t proto_len = (uint8_t)strlen(proto);
    uint8_t msg_len = (uint8_t)strlen(msg_type);
    size_t total_len = 1 + proto_len + 1 + msg_len + 36 + 36 + 32 + 32 + 4;

    if (max_len < total_len) return 0;
    if (strlen(session_id) != 36 || strlen(device_id) != 36) return 0;

    size_t offset = 0;
    out_buf[offset++] = proto_len;
    memcpy(out_buf + offset, proto, proto_len); offset += proto_len;

    out_buf[offset++] = msg_len;
    memcpy(out_buf + offset, msg_type, msg_len); offset += msg_len;

    memcpy(out_buf + offset, session_id, 36); offset += 36;
    memcpy(out_buf + offset, device_id, 36); offset += 36;
    memcpy(out_buf + offset, app_chal, 32); offset += 32;
    memcpy(out_buf + offset, dev_chal, 32); offset += 32;

    uint32_t seq_be = htonl(sequence_number);
    memcpy(out_buf + offset, &seq_be, 4); offset += 4;

    return offset;
}

size_t eh_prov1_fragment_payload(const uint8_t *payload, size_t payload_len,
                                 uint8_t frame_index, uint8_t *out_frame, size_t max_frame_len)
{
    const size_t max_chunk_len = 16; // 2 byte header (frame_index, total_frames) + 16 payload bytes = 18 bytes <= 20 bytes
    size_t total_frames = (payload_len + max_chunk_len - 1) / max_chunk_len;
    if (total_frames == 0) total_frames = 1;

    if (frame_index >= total_frames) return 0;

    size_t start_offset = frame_index * max_chunk_len;
    size_t chunk_len = payload_len - start_offset;
    if (chunk_len > max_chunk_len) chunk_len = max_chunk_len;

    if (max_frame_len < 2 + chunk_len) return 0;

    out_frame[0] = frame_index;
    out_frame[1] = (uint8_t)total_frames;
    memcpy(out_frame + 2, payload + start_offset, chunk_len);

    return 2 + chunk_len;
}

esp_err_t eh_prov1_process_frame(const uint8_t *frame, size_t frame_len,
                                 uint8_t *out_msg, size_t *out_msg_len, bool *out_is_complete)
{
    if (frame_len < 2) return ESP_ERR_INVALID_ARG;
    uint8_t frame_index = frame[0];
    uint8_t total_frames = frame[1];
    size_t chunk_len = frame_len - 2;

    if (frame_index == 0) {
        // Reset reassembly buffer for new message
        s_framing.current_len = 0;
        s_framing.next_expected_frame = 0;
        s_framing.total_frames = total_frames;
        s_framing.in_progress = true;
    } else {
        if (!s_framing.in_progress || frame_index != s_framing.next_expected_frame || total_frames != s_framing.total_frames) {
            ESP_LOGE(TAG, "Out of order BLE frame received: index %d, expected %d", frame_index, s_framing.next_expected_frame);
            s_framing.in_progress = false;
            return ESP_ERR_INVALID_SEQUENCE;
        }
    }

    if (s_framing.current_len + chunk_len > sizeof(s_framing.reassembly_buf)) {
        s_framing.in_progress = false;
        return ESP_ERR_NO_MEM;
    }

    memcpy(s_framing.reassembly_buf + s_framing.current_len, frame + 2, chunk_len);
    s_framing.current_len += chunk_len;
    s_framing.next_expected_frame++;

    if (s_framing.next_expected_frame == total_frames) {
        // Reassembly complete
        if (*out_msg_len < s_framing.current_len) {
            s_framing.in_progress = false;
            return ESP_ERR_NO_MEM;
        }
        memcpy(out_msg, s_framing.reassembly_buf, s_framing.current_len);
        *out_msg_len = s_framing.current_len;
        *out_is_complete = true;
        s_framing.in_progress = false;
    } else {
        *out_is_complete = false;
    }

    return ESP_OK;
}

static esp_err_t compute_hmac_sha256(const uint8_t *key, size_t key_len,
                                     const uint8_t *data, size_t data_len,
                                     uint8_t out_mac[32])
{
    const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (!md_info) return ESP_FAIL;
    return mbedtls_md_hmac(md_info, key, key_len, data, data_len, out_mac) == 0 ? ESP_OK : ESP_FAIL;
}

static esp_err_t derive_hkdf_session_key(const uint8_t ikm[32],
                                          const uint8_t app_chal[32],
                                          const uint8_t dev_chal[32],
                                          const char *session_id,
                                          const char *device_id,
                                          uint8_t out_key[32])
{
    uint8_t salt[64];
    memcpy(salt, app_chal, 32);
    memcpy(salt + 32, dev_chal, 32);

    char info[128];
    snprintf(info, sizeof(info), "EH-PROV/1|WIFI|%s|%s", session_id, device_id);

    const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (!md_info) return ESP_FAIL;

    int ret = mbedtls_hkdf(md_info, salt, sizeof(salt),
                           ikm, 32,
                           (const unsigned char *)info, strlen(info),
                           out_key, 32);
    return ret == 0 ? ESP_OK : ESP_FAIL;
}

esp_err_t eh_prov1_init(void)
{
    memset(&s_session, 0, sizeof(s_session));
    memset(&s_framing, 0, sizeof(s_framing));
    s_state = EH_PROV1_STATE_FACTORY_NEW;
    ESP_LOGI(TAG, "EH-PROV/1 state machine initialized");
    return ESP_OK;
}

eh_prov1_state_t eh_prov1_get_state(void)
{
    return s_state;
}

void eh_prov1_set_state(eh_prov1_state_t state)
{
    s_state = state;
    ESP_LOGI(TAG, "EH-PROV/1 state changed to %d", s_state);
}

esp_err_t eh_prov1_on_mtls_registration_success(void)
{
    ESP_LOGI(TAG, "mTLS Device Registration succeeded. Setting commissioningSecretConsumed = true");
    factory_identity_v2_set_secret_consumed(true);
    s_state = EH_PROV1_STATE_ACTIVE;
    return ESP_OK;
}

esp_err_t eh_prov1_handle_message(const uint8_t *in_data, size_t in_len,
                                  uint8_t *out_data, size_t *out_len, size_t max_out_len)
{
    const factory_identity_v2_t *id = factory_identity_v2_get();

    // Check if commissioning secret is consumed and device is ACTIVE
    if (id->commissioning_secret_consumed && s_state == EH_PROV1_STATE_ACTIVE) {
        ESP_LOGE(TAG, "Commissioning disabled. Device is ACTIVE and secret is consumed.");
        return ESP_ERR_INVALID_STATE;
    }

    if (in_len < 2) return ESP_ERR_INVALID_ARG;
    uint8_t msg_type = in_data[0];

    if (msg_type == EH_PROV1_MSG_HELLO) {
        // HELLO (seq=0): parse app_challenge and generate device_challenge
        if (in_len < 1 + 36 + 32) return ESP_ERR_INVALID_ARG;

        memcpy(s_session.session_id, in_data + 1, 36);
        s_session.session_id[36] = '\0';
        memcpy(s_session.app_challenge, in_data + 37, 32);

        esp_fill_random(s_session.device_challenge, 32);
        s_session.expected_seq = 2;
        s_state = EH_PROV1_STATE_COMMISSIONING;

        // Construct HELLO_ACK response: msg_type (1B) + device_challenge (32B) + seq (4B BE)
        if (max_out_len < 37) return ESP_ERR_NO_MEM;
        out_data[0] = EH_PROV1_MSG_HELLO_ACK;
        memcpy(out_data + 1, s_session.device_challenge, 32);
        uint32_t seq1 = htonl(1);
        memcpy(out_data + 33, &seq1, 4);
        *out_len = 37;
        return ESP_OK;
    }

    if (msg_type == EH_PROV1_MSG_AUTH) {
        // AUTH (seq=2): verify appProof (32B)
        if (s_state != EH_PROV1_STATE_COMMISSIONING) return ESP_ERR_INVALID_STATE;
        if (in_len < 1 + 32) return ESP_ERR_INVALID_ARG;

        const uint8_t *app_proof = in_data + 1;
        uint8_t transcript_buf[256];
        size_t t_len = eh_prov1_encode_transcript("APP_PROOF", s_session.session_id,
                                                   id->device_id, s_session.app_challenge,
                                                   s_session.device_challenge, 2,
                                                   transcript_buf, sizeof(transcript_buf));
        if (t_len == 0) return ESP_FAIL;

        uint8_t expected_app_proof[32];
        if (compute_hmac_sha256(id->commissioning_secret, 32, transcript_buf, t_len, expected_app_proof) != ESP_OK) {
            return ESP_FAIL;
        }

        if (constant_time_memcmp(app_proof, expected_app_proof, 32) != 0) {
            ESP_LOGE(TAG, "appProof verification failed! Mismatch.");
            s_state = EH_PROV1_STATE_FAILED;
            return ESP_ERR_INVALID_RESPONSE;
        }

        // App proof valid -> compute deviceProof
        size_t dev_t_len = eh_prov1_encode_transcript("DEVICE_PROOF", s_session.session_id,
                                                       id->device_id, s_session.app_challenge,
                                                       s_session.device_challenge, 3,
                                                       transcript_buf, sizeof(transcript_buf));
        uint8_t device_proof[32];
        compute_hmac_sha256(id->commissioning_secret, 32, transcript_buf, dev_t_len, device_proof);

        // Derive session key
        derive_hkdf_session_key(id->commissioning_secret, s_session.app_challenge,
                                s_session.device_challenge, s_session.session_id,
                                id->device_id, s_session.session_key);

        s_session.is_authenticated = true;
        s_state = EH_PROV1_STATE_AUTHENTICATED;

        // Construct AUTH_ACK response: msg_type (1B) + device_proof (32B) + seq (4B BE)
        if (max_out_len < 37) return ESP_ERR_NO_MEM;
        out_data[0] = EH_PROV1_MSG_AUTH_ACK;
        memcpy(out_data + 1, device_proof, 32);
        uint32_t seq3 = htonl(3);
        memcpy(out_data + 33, &seq3, 4);
        *out_len = 37;
        return ESP_OK;
    }

    if (msg_type == EH_PROV1_MSG_WIFI_CRED) {
        // WIFI_CRED (seq=4): decrypt AES-256-GCM
        if (s_state != EH_PROV1_STATE_AUTHENTICATED || !s_session.is_authenticated) {
            return ESP_ERR_INVALID_STATE;
        }

        // Payload: nonce (12B) + ciphertext + tag (16B)
        if (in_len < 1 + 12 + 16) return ESP_ERR_INVALID_ARG;
        const uint8_t *nonce = in_data + 1;
        size_t cipher_len = in_len - 1 - 12 - 16;
        const uint8_t *ciphertext = in_data + 13;
        const uint8_t *tag = ciphertext + cipher_len;

        uint8_t aad_buf[256];
        size_t aad_len = eh_prov1_encode_transcript("WIFI", s_session.session_id,
                                                     id->device_id, s_session.app_challenge,
                                                     s_session.device_challenge, 4,
                                                     aad_buf, sizeof(aad_buf));

        mbedtls_gcm_context gcm;
        mbedtls_gcm_init(&gcm);
        int ret = mbedtls_gcm_setkey(&gcm, MBEDTLS_CIPHER_ID_AES, s_session.session_key, 256);
        if (ret != 0) {
            mbedtls_gcm_free(&gcm);
            return ESP_FAIL;
        }

        uint8_t plaintext[256];
        ret = mbedtls_gcm_auth_decrypt(&gcm, cipher_len, nonce, 12, aad_buf, aad_len,
                                       tag, 16, ciphertext, plaintext);
        mbedtls_gcm_free(&gcm);

        if (ret != 0) {
            ESP_LOGE(TAG, "AES-256-GCM auth_decrypt failed! Tampered payload.");
            s_state = EH_PROV1_STATE_FAILED;
            return ESP_ERR_INVALID_RESPONSE;
        }

        plaintext[cipher_len] = '\0';
        ESP_LOGI(TAG, "Wi-Fi credentials decrypted and verified successfully via GCM tag!");
        s_state = EH_PROV1_STATE_REGISTRATION_PENDING;

        // Construct WIFI_ACK response
        if (max_out_len < 6) return ESP_ERR_NO_MEM;
        out_data[0] = EH_PROV1_MSG_WIFI_ACK;
        out_data[1] = 1; // Success
        uint32_t seq5 = htonl(5);
        memcpy(out_data + 2, &seq5, 4);
        *out_len = 6;
        return ESP_OK;
    }

    return ESP_ERR_INVALID_ARG;
}
