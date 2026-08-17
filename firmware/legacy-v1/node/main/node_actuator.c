#include "node_actuator.h"

#include "driver/gpio.h"
#include "esp_err.h"

/* GPIO 27 drives only a correctly rated MOSFET or relay input, never the load. */
#define MIST_MAKER_GPIO GPIO_NUM_27

static bool s_mist_maker_on;

void node_actuator_init(void)
{
    const gpio_config_t output = {
        .pin_bit_mask = 1ULL << MIST_MAKER_GPIO,
        .mode = GPIO_MODE_OUTPUT,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&output));
    node_actuator_set_mist_maker(false); /* Safe state after every boot. */
}

bool node_actuator_mist_maker_is_on(void)
{
    return s_mist_maker_on;
}

void node_actuator_set_mist_maker(bool enabled)
{
    s_mist_maker_on = enabled;
    ESP_ERROR_CHECK(gpio_set_level(MIST_MAKER_GPIO, enabled ? 1 : 0));
}
