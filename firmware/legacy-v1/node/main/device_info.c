#include "device_info.h"

#include <stdio.h>

#include "factory_identity.h"
#include "node_identity.h"
#include "node_protocol.h"
#include "product_profile.h"
#include "user_configuration.h"

size_t device_info_make_json(char *buffer, size_t buffer_size)
{
    const product_profile_t *product = product_profile_get();
    const user_configuration_t *user = user_configuration_get();
    int length = snprintf(
        buffer, buffer_size,
        "{\"schemaVersion\":1,\"product\":{\"brand\":\"%s\",\"name\":\"%s\","
        "\"model\":\"%s\",\"hardwareRevision\":\"%s\",\"firmwareVersion\":\"%s\","
        "\"capabilities\":%lu},\"device\":{\"deviceId\":\"%s\",\"serialNumber\":\"%s\","
        "\"bleName\":\"%s\",\"state\":%d,\"developmentIdentity\":%s},"
        "\"customer\":{\"bound\":%s}}",
        product->brand, product->product_name, product->model, product->hardware_revision,
        product->firmware_version, (unsigned long)product->capability_mask,
        factory_identity_device_id(), factory_identity_serial_number(), node_identity_ble_name(),
        node_protocol_state(), factory_identity_is_development() ? "true" : "false",
        user->is_bound_to_home ? "true" : "false");
    return length > 0 && (size_t)length < buffer_size ? (size_t)length : 0;
}
