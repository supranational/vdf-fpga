/*
  Copyright 2019 Supranational LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

#ifndef _CONFIG_H_
#define _CONFIG_H_

#include <gmp.h>

#define T_LEN                 64

#define MSU_BYTES_PER_WORD    4
#define MSU_WORD_LEN          (MSU_BYTES_PER_WORD*8)
#define EXTRA_ELEMENTS        2
#define NUM_SEGMENTS          4

// Constants for Ozturk construction
#define REDUNDANT_ELEMENTS    2
#define WORD_LEN              16

// Use to define size of word on cpp side (1,2,4,8) depending on bit_len
#define BN_BUFFER_SIZE        4  // top.sv BIT_LEN = 17-32

// Use to create offset when using larger words for bit_len
// Such as when bit_len in top.sv is 17b and is 16b here, offset is 16
#define BN_BUFFER_OFFSET      0

void bn_shl(mpz_t bn, int bits);
void bn_shr(mpz_t bn, int bits);
void bn_init_mask(mpz_t mask, int bits);

#endif
