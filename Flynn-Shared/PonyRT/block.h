//
//  block.h
//  Flynn
//
//  Created by Rocco Bowling on 5/12/20.
//  Copyright © 2020 Rocco Bowling. All rights reserved.
//

#ifndef block_h
#define block_h

#include "ponyrt.h"

#define USE_CUSTOM_BLOCK_COPY 1

void Block_release_pony(PonyCallback p);
PonyCallback Block_copy_pony(PonyCallback p);

#endif /* block_h */
