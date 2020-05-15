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

void FastBlock_release_pony(FastBlockCallback p);
FastBlockCallback FastBlock_copy_pony(FastBlockCallback p);

void Block_release_pony(BlockCallback p);
BlockCallback Block_copy_pony(BlockCallback p);

#endif /* block_h */
