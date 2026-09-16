
// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#ifndef dedicated_h
#define dedicated_h

#include <stdbool.h>
#include <stdint.h>

#include "actor.h"

void ponyint_dedicated_init(void);

pony_actor_t* ponyint_dedicated_create_actor(const char* name, int32_t coreAffinity);

void ponyint_dedicated_wake(pony_actor_t* actor);

bool ponyint_dedicated_is_idle(void);

void ponyint_dedicated_stop_all(void);

int32_t ponyint_dedicated_count(void);

#endif
