//
//  block.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>

#include "block.h"
#include "pool.h"
#include "alloc.h"
#include "ponyrt.h"

#if !USE_CUSTOM_BLOCK_COPY

void Block_release_pony(PonyCallback p) {
    Block_release(p);
}

PonyCallback Block_copy_pony(PonyCallback p) {
    return Block_copy(p);
}

#else

enum {
    BLOCK_DEALLOCATING =      (0x0001),  // runtime
    BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime
    BLOCK_NEEDS_FREE =        (1 << 24), // runtime
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // compiler
    BLOCK_HAS_CTOR =          (1 << 26), // compiler: helpers have C++ code
    BLOCK_IS_GC =             (1 << 27), // runtime
    BLOCK_IS_GLOBAL =         (1 << 28), // compiler
    BLOCK_USE_STRET =         (1 << 29), // compiler: undefined if !BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE  =    (1 << 30), // compiler
    BLOCK_HAS_EXTENDED_LAYOUT=(1 << 31)  // compiler
};


void * _NSConcreteMallocBlock[32];

#define BLOCK_DESCRIPTOR_1 1
struct Block_descriptor_1 {
    uintptr_t reserved;
    uintptr_t size;
};

#define BLOCK_DESCRIPTOR_2 1
struct Block_descriptor_2 {
    // requires BLOCK_HAS_COPY_DISPOSE
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
};

#define BLOCK_DESCRIPTOR_3 1
struct Block_descriptor_3 {
    // requires BLOCK_HAS_SIGNATURE
    const char *signature;
    const char *layout;     // contents depend on BLOCK_HAS_EXTENDED_LAYOUT
};

struct Block_layout {
    void *isa;
    volatile int32_t flags; // contains ref count
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor_1 *descriptor;
    // imported variables
};


static struct Block_descriptor_2 * _Block_descriptor_2(struct Block_layout *aBlock)
{
    if (! (aBlock->flags & BLOCK_HAS_COPY_DISPOSE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct Block_descriptor_1);
    return (struct Block_descriptor_2 *)desc;
}

static void _Block_call_copy_helper(void *result, struct Block_layout *aBlock)
{
    struct Block_descriptor_2 *desc = _Block_descriptor_2(aBlock);
    if (!desc) return;

    (*desc->copy)(result, aBlock); // do fixup
}

static void _Block_call_dispose_helper(struct Block_layout *aBlock)
{
    struct Block_descriptor_2 *desc = _Block_descriptor_2(aBlock);
    if (!desc) return;

    (*desc->dispose)(aBlock);
}

void Block_release_pony(PonyCallback p) {
    struct Block_layout *aBlock = (struct Block_layout *)p;
    
    _Block_call_dispose_helper(aBlock);
    
    ponyint_pool_free_size(aBlock->descriptor->size, aBlock);
}

PonyCallback Block_copy_pony(PonyCallback p) {
    // We've re-implemented Block_copy to allocate memory in this pony message to
    // contain the contents of the block. This avoids extraneous calls to malloc
    // (which inherently locks, which is bad)
    struct Block_layout *aBlock = (struct Block_layout *)p;
    
    struct Block_layout *result = ponyint_pool_alloc_size(aBlock->descriptor->size);
    if (!result) return NULL;
    memmove(result, aBlock, aBlock->descriptor->size); // bitcopy first
    
    // reset refcount
    result->flags &= ~(BLOCK_REFCOUNT_MASK|BLOCK_DEALLOCATING);    // XXX not needed
    result->flags |= BLOCK_NEEDS_FREE | 2;  // logical refcount 1
    result->isa = _NSConcreteMallocBlock;
    _Block_call_copy_helper(result, aBlock);
    return (PonyCallback)result;
}

#endif
