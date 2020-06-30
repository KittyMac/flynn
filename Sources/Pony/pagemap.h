// Note: This code is derivative of the Pony runtime; see README.md for more details

#include <sys/types.h>

#ifndef mem_pagemap_h
#define mem_pagemap_h

typedef struct chunk_t chunk_t;

chunk_t* ponyint_pagemap_get(const void* addr);

void ponyint_pagemap_set(const void* addr, chunk_t* chunk);

#endif
