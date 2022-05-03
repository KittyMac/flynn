// Note: This code is derivative of the Pony runtime; see README.md for more details

#include "platform.h"

#include "ponyrt.h"

#ifndef memory_h
#define memory_h

extern void* ponyint_pool_alloc(size_t size);
extern void* ponyint_pool_free(void* p, size_t size);
extern pony_msg_t* pony_alloc_msg(size_t size, uint32_t msgId);
extern void ponyint_pool_thread_cleanup();
extern void ponyint_update_memory_usage();

extern size_t ponyint_total_memory();
extern size_t ponyint_max_memory();
extern size_t ponyint_usafe_mapped_memory();

// void ponyint_update_memory_usage(void);
// size_t ponyint_total_memory(void);
// size_t ponyint_max_memory(void);
// size_t ponyint_usafe_mapped_memory();
// void* ponyint_virt_alloc(size_t bytes);
// void ponyint_virt_free(void* p, size_t bytes);

#endif
