#pragma once

#include <stdbool.h>

void node_actuator_init(void);
bool node_actuator_mist_maker_is_on(void);
void node_actuator_set_mist_maker(bool enabled);

