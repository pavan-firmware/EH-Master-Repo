#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "esp_err.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "ble_server.h"
#include "factory_identity.h"
#include "node_actuator.h"
#include "node_identity.h"
#include "node_protocol.h"
#include "user_configuration.h"

#define TELEMETRY_INTERVAL_MS 5000

static const char *TAG = "smart_home_node";

static void telemetry_task(void *param)
{
    (void)param;
    while (true) {
        ble_server_publish_state();
        vTaskDelay(pdMS_TO_TICKS(TELEMETRY_INTERVAL_MS));
    }
}

void app_main(void)
{
    esp_err_t result = nvs_flash_init();
    if (result == ESP_ERR_NVS_NO_FREE_PAGES || result == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        result = nvs_flash_init();
    }
    ESP_ERROR_CHECK(result);

    node_identity_init();
    factory_identity_init();
    user_configuration_init();
    node_protocol_init();
    node_actuator_init();
    ESP_ERROR_CHECK(ble_server_init());

    BaseType_t task_created = xTaskCreate(telemetry_task, "telemetry", 3072,
                                           NULL, 5, NULL);
    ESP_ERROR_CHECK(task_created == pdPASS ? ESP_OK : ESP_ERR_NO_MEM);

    ESP_LOGI(TAG, "Node %s ready in state %d", node_identity_ble_name(),
             node_protocol_state());
}
