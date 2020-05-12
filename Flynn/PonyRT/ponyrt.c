//
//  ponyrt.c
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

#include <stdlib.h>

#include "ponyrt.h"

#include "messageq.h"

static bool pony_is_inited = false;

typedef struct {
    messageq_t q;
    uint64_t renderFrameNumber;
} TestMessage;

void pony_init() {
    if (pony_is_inited == false) {
        pony_is_inited = true;
        
        
        TestMessage * msg = (TestMessage *)calloc(sizeof(TestMessage), 1);
        ponyint_messageq_init(&msg->q);
        
        fprintf(stderr, "after ponyint_messageq_init()\n");
        
        ponyint_messageq_destroy(&msg->q);
        
        fprintf(stderr, "after ponyint_messageq_destroy()\n");
        
        free(msg);
    }
}

void pony_stop() {
    fprintf(stderr, "pony_stop()\n");
}
