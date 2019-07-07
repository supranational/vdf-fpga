#!/usr/bin/python3

################################################################################
# Copyright 2019 Supranational LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################
import math
import random

import sys
sys.path.append('../../primitives/model')

import primitives as p

def print_poly_hex(name, p_v):
    print(name, "len %d: " % len(p_v), end='')
    for i in range (len(p_v)):
    #for i in range (10):
        print("%04x," % p_v[i], end='')
        #print("%04x," % p_v[len(p_v)-i-1], end='')
    print("")

def print_grid(grid, grid_size, grid_num_elements):
   for x in range (grid_num_elements):
      for y in range (grid_size):
         print('{0:06x} '.format(p.bits_to_int(grid[y][x])), end='')
      print('')

def print_compressed_grid(subtotal):
   for i in subtotal:
      print('{0:06x} '.format(i), end='')
   print('')

# Partially reduce the polynomial by adding the high bits into
# the next coefficient.
def partial_reduction(p_v, offset, elements, word_len):
    for i in range (elements-1, 0, -1):
        p_v[i+offset]  += p_v[i+offset-1] >> word_len 
        p_v[i+offset-1] = p_v[i+offset-1] & (2**word_len- 1)

def set_grid_5_cycle(cycle, sqr_in_seg, redundant_elements, 
                     nonredundant_elements, num_segments, bit_len, word_len):
   #############################################################################
   # Parameters
   #############################################################################
   REDUNDANT_ELEMENTS    = redundant_elements
   NONREDUNDANT_ELEMENTS = nonredundant_elements
   NUM_SEGMENTS          = num_segments
   BIT_LEN               = bit_len
   WORD_LEN              = word_len

   NUM_MULTIPLIERS       = 2;

   NUM_ELEMENTS          = REDUNDANT_ELEMENTS + NONREDUNDANT_ELEMENTS
   COL_BIT_LEN           = (BIT_LEN*2)-WORD_LEN
   SEGMENT_ELEMENTS      = (NONREDUNDANT_ELEMENTS // NUM_SEGMENTS)
   MUL_NUM_ELEMENTS      = SEGMENT_ELEMENTS + REDUNDANT_ELEMENTS

   GRID_SIZE             = ((MUL_NUM_ELEMENTS*2) + SEGMENT_ELEMENTS + 1)

   EXTRA_MUL_TREE_BITS   = math.ceil(math.log2(MUL_NUM_ELEMENTS))     \
                           if (BIT_LEN > WORD_LEN) else               \
                           math.ceil(math.log2(NUM_ELEMENTS*2))
   MUL_BIT_LEN           = ((BIT_LEN*2) - WORD_LEN)     +             \
                           EXTRA_MUL_TREE_BITS

   #TODO - need better method here, not using large conditionals though
   MAX_VALUE             = ((2**BIT_LEN)-1)           +               \
                           (((2**WORD_LEN)-1) << 2)   +               \
                           (((2**(MUL_BIT_LEN-WORD_LEN))-1) << 2)

   GRID_BIT_LEN          = math.ceil(math.log2(MAX_VALUE))

   WORD_MASK             = (2**WORD_LEN) - 1

   # Input mux select for multiply factors
   mul0_A = [3, 2, 3, 2, 0]
   mul0_B = [2, 2, 0, 0, 0]
   mul1_A = [3, 3, 2, 1, 1]
   mul1_B = [3, 1, 1, 1, 0]

   mul0_result_shift = [1, 0, 1, 1, 0]  # Shift mul0 result
   mul1_result_shift = [0, 1, 1, 0, 1]  # Shift mul0 result
   mul1_first        = [0, 1, 1, 1, 0]  # mul1 result in first or second segment

   # select factors to multiply
   c0, s0 = p.multiply(sqr_in_seg[mul0_A[cycle]], sqr_in_seg[mul0_B[cycle]],
                       MUL_NUM_ELEMENTS, MUL_BIT_LEN, WORD_LEN)
   c1, s1 = p.multiply(sqr_in_seg[mul1_A[cycle]], sqr_in_seg[mul1_B[cycle]],
                       MUL_NUM_ELEMENTS, MUL_BIT_LEN, WORD_LEN)

   # reset grid
   grid   = [[[0 for z in range (GRID_BIT_LEN)] for x in range (9)]
             for y in range (GRID_SIZE)]

   # Grid rows
   # 0 - mul0 carry low
   # 1 - mul0 carry high
   # 2 - mul0 sum   low
   # 3 - mul0 sum   high
   # 4 - mul1 carry low
   # 5 - mul1 carry high
   # 6 - mul1 sum   low
   # 7 - mul1 sum   high
   # 8 - previous cycle result

   # Shift is required for x2 of multiply result used in square operation

   # Number of grid columns is based on the number of multiplier elements.
   # Most elements of the grid are 0.  Based on the number of redundant 
   #  elements required, the upper elements are used only for one cycle.

   for j in range (MUL_NUM_ELEMENTS*2):
      if (mul0_result_shift[cycle] == 1):
         grid[j][0]   = p.int_to_bits(((c0[j]<<1) & WORD_MASK), GRID_BIT_LEN)
         grid[j+1][1] = p.int_to_bits(((c0[j]<<1) >> WORD_LEN), GRID_BIT_LEN)
         grid[j][2]   = p.int_to_bits(((s0[j]<<1) & WORD_MASK), GRID_BIT_LEN)
         grid[j+1][3] = p.int_to_bits(((s0[j]<<1) >> WORD_LEN), GRID_BIT_LEN)
      else: # No shift
         grid[j][0]   = p.int_to_bits((c0[j] & WORD_MASK), GRID_BIT_LEN)
         grid[j+1][1] = p.int_to_bits((c0[j] >> WORD_LEN), GRID_BIT_LEN)
         grid[j][2]   = p.int_to_bits((s0[j] & WORD_MASK), GRID_BIT_LEN)
         grid[j+1][3] = p.int_to_bits((s0[j] >> WORD_LEN), GRID_BIT_LEN)

      if (mul1_first[cycle] == 1):
         if (mul1_result_shift[cycle] == 1):
            grid[j][4]   = p.int_to_bits(((c1[j]<<1)&WORD_MASK),GRID_BIT_LEN)
            grid[j+1][5] = p.int_to_bits(((c1[j]<<1)>>WORD_LEN),GRID_BIT_LEN)
            grid[j][6]   = p.int_to_bits(((s1[j]<<1)&WORD_MASK),GRID_BIT_LEN)
            grid[j+1][7] = p.int_to_bits(((s1[j]<<1)>>WORD_LEN),GRID_BIT_LEN)
         else: # No shift
            grid[j][4]   = p.int_to_bits((c1[j] & WORD_MASK), GRID_BIT_LEN)
            grid[j+1][5] = p.int_to_bits((c1[j] >> WORD_LEN), GRID_BIT_LEN)
            grid[j][6]   = p.int_to_bits((s1[j] & WORD_MASK), GRID_BIT_LEN)
            grid[j+1][7] = p.int_to_bits((s1[j] >> WORD_LEN), GRID_BIT_LEN)
      else:
         if (mul1_result_shift[cycle] == 1):
            grid[j+SEGMENT_ELEMENTS][4]          = \
               p.int_to_bits(((c1[j] << 1) & WORD_MASK), GRID_BIT_LEN)
            grid[j+1+SEGMENT_ELEMENTS][5]        = \
               p.int_to_bits(((c1[j] << 1) >> WORD_LEN), GRID_BIT_LEN)
            grid[j+SEGMENT_ELEMENTS][6]          = \
               p.int_to_bits(((s1[j] << 1) & WORD_MASK), GRID_BIT_LEN)
            grid[j+1+SEGMENT_ELEMENTS][7]        = \
               p.int_to_bits(((s1[j] << 1) >> WORD_LEN), GRID_BIT_LEN)
         else: # No shift
            grid[j+SEGMENT_ELEMENTS][4]          = \
               p.int_to_bits((c1[j] & WORD_MASK), GRID_BIT_LEN)
            grid[j+1+SEGMENT_ELEMENTS][5]        = \
               p.int_to_bits((c1[j] >> WORD_LEN), GRID_BIT_LEN)
            grid[j+SEGMENT_ELEMENTS][6]          = \
               p.int_to_bits((s1[j] & WORD_MASK), GRID_BIT_LEN)
            grid[j+1+SEGMENT_ELEMENTS][7]        = \
               p.int_to_bits((s1[j] >> WORD_LEN), GRID_BIT_LEN)

   return grid

def add_prev_to_grid(grid, p_v, grid_offset, length, grid_bit_len):
   GRID_BIT_LEN = grid_bit_len

   for i in range (length):
      grid[i + grid_offset][8] = p.int_to_bits(p_v[i], GRID_BIT_LEN)

   return grid

def compress_grid(grid, grid_size, grid_bit_len, word_len):
   GRID_SIZE    = grid_size
   GRID_BIT_LEN = grid_bit_len
   WORD_LEN     = word_len

   cg = GRID_SIZE*[0]
   sg = GRID_SIZE*[0]
   for j in range (GRID_SIZE):
      result = p.compressor_tree(grid[j], GRID_BIT_LEN)
      cg[j]  = p.bits_to_int(result[0])
      sg[j]  = p.bits_to_int(result[1])

   sub_totals = GRID_SIZE*[0]
   for j in range (GRID_SIZE):
      sub_totals[j] = cg[j] + sg[j]

   partial_reduction(sub_totals, 0, GRID_SIZE, WORD_LEN)

   return sub_totals

def modular_square(sqr_in, mod_in, redLUT, redundant_elements, 
                   nonredundant_elements, num_segments, bit_len, word_len, 
                   stats):

   #############################################################################
   # Parameters
   #############################################################################
   REDUNDANT_ELEMENTS    = redundant_elements
   NONREDUNDANT_ELEMENTS = nonredundant_elements
   NUM_SEGMENTS          = num_segments
   BIT_LEN               = bit_len
   WORD_LEN              = word_len

   NUM_MULTIPLIERS       = 2;

   NUM_ELEMENTS          = REDUNDANT_ELEMENTS + NONREDUNDANT_ELEMENTS
   COL_BIT_LEN           = (BIT_LEN*2)-WORD_LEN
   SEGMENT_ELEMENTS      = (NONREDUNDANT_ELEMENTS // NUM_SEGMENTS)
   MUL_NUM_ELEMENTS      = SEGMENT_ELEMENTS + REDUNDANT_ELEMENTS

   EXTRA_ELEMENTS        = 2;
   ONE_SEGMENT           = SEGMENT_ELEMENTS     + REDUNDANT_ELEMENTS + \
                           EXTRA_ELEMENTS
   TWO_SEGMENTS          = (SEGMENT_ELEMENTS*2) + REDUNDANT_ELEMENTS + \
                           EXTRA_ELEMENTS
   THREE_SEGMENTS        = (SEGMENT_ELEMENTS*3) + REDUNDANT_ELEMENTS + \
                           EXTRA_ELEMENTS

   GRID_SIZE             = ((MUL_NUM_ELEMENTS*2) + SEGMENT_ELEMENTS + 1)

   EXTRA_MUL_TREE_BITS   = math.ceil(math.log2(MUL_NUM_ELEMENTS))     \
                           if (BIT_LEN > WORD_LEN) else               \
                           math.ceil(math.log2(NUM_ELEMENTS*2))
   MUL_BIT_LEN           = ((BIT_LEN*2) - WORD_LEN)     +             \
                           EXTRA_MUL_TREE_BITS

   #TODO - need better method here, not using large conditionals though
   MAX_VALUE             = ((2**BIT_LEN)-1)           +               \
                           (((2**WORD_LEN)-1) << 2)   +               \
                           (((2**(MUL_BIT_LEN-WORD_LEN))-1) << 2)

   GRID_BIT_LEN          = math.ceil(math.log2(MAX_VALUE))

   WORD_MASK             = (2**WORD_LEN) - 1
   LOOK_UP_WIDTH         = WORD_LEN // 2
   LUT_SIZE              = 2**LOOK_UP_WIDTH 
   LUT_MASK              = (2**LOOK_UP_WIDTH)-1

   #############################################################################
   # Input
   #############################################################################
   sqr_in_v = NUM_ELEMENTS*[0]
   for i in range (NUM_ELEMENTS):
      sqr_in_v[i] = (sqr_in >> (WORD_LEN * i)) & WORD_MASK


   # Every cycle there are more elements than needed for all except last cycle
   sqr_in_seg = [[0 for x in range (MUL_NUM_ELEMENTS)] 
                 for y in range (NUM_SEGMENTS)]

   for i in range (NUM_SEGMENTS):
      for j in range (SEGMENT_ELEMENTS):
         sqr_in_seg[i][j] = sqr_in_v[(i*SEGMENT_ELEMENTS)+j]

   # Last cycle holds the extra redundant elements for overflow
   for i in range (REDUNDANT_ELEMENTS, 0, -1):
      sqr_in_seg[NUM_SEGMENTS-1][MUL_NUM_ELEMENTS-i] = sqr_in_v[NUM_ELEMENTS-i]

   #############################################################################
   # Cycle 0
   #############################################################################
   cycle = 0

   # |---|-----------------|
   # |   |      W3*W3      |
   # |---|-----------------|
   #          |---|-----------------|
   #  x2      |   |      W3*W2      |
   #          |---|-----------------|

   grid_cycle_0 = set_grid_5_cycle(cycle, sqr_in_seg, redundant_elements, 
                        nonredundant_elements, num_segments, bit_len, word_len)

   #############################################################################
   # Cycle 1
   #############################################################################
   cycle = 1

   #                       |-----------------|
   #                       |      W2*W2      |
   #                       |-----------------|
   #                   |---|-----------------|
   #  x2               |   |      W3*W1      |
   #                   |---|-----------------|

   grid_cycle_1 = set_grid_5_cycle(cycle, sqr_in_seg, redundant_elements, 
                        nonredundant_elements, num_segments, bit_len, word_len)

   #############################################################################
   # Cycle 2
   #############################################################################
   cycle = 2

   #                                |-----------------|
   #  x2                            |      W2*W1      |
   #                                |-----------------|
   #                            |---|-----------------|
   #  x2                        |   |      W3*W0      |
   #                            |---|-----------------|

   grid_cycle_2 = set_grid_5_cycle(cycle, sqr_in_seg, redundant_elements, 
                        nonredundant_elements, num_segments, bit_len, word_len)

   # |---|-----------------|
   # |   |      W3*W3      |
   # |---|-----------------|
   #          |---|-----------------|
   #  x2      |   |      W3*W2      |
   #          |---|-----------------|
   #     +
   #     ----------------------------------------------------------------------
   # |---|--------|--------|--------|
   # |   |   V7   |   V6   |   V5*  |
   # |---|--------|--------|--------|

   sub_totals_cycle_0 = compress_grid(grid_cycle_0, GRID_SIZE, 
                                      GRID_BIT_LEN, WORD_LEN)

   #print('C0 grid')
   #print_grid(grid_cycle_0, GRID_SIZE, 9)
   #print('C0 subtotal')
   #print_compressed_grid(sub_totals_cycle_0)

   v5_partial = SEGMENT_ELEMENTS*[0]
   for j in range (SEGMENT_ELEMENTS):
      v5_partial[j] = sub_totals_cycle_0[j]

   v7v6 = (TWO_SEGMENTS)*[0]
   for j in range (TWO_SEGMENTS):
      v7v6[j] = sub_totals_cycle_0[j + SEGMENT_ELEMENTS]

   for j in range (REDUNDANT_ELEMENTS + EXTRA_ELEMENTS):
      if (v7v6[j + (SEGMENT_ELEMENTS*2)] > 0):
         stats[str('V7V6_Extra_'+str(j))] = hex(v7v6[j + (SEGMENT_ELEMENTS*2)])
      elif (str('V7V6_Extra_'+str(j)) in stats):
         del stats[str('V7V6_Extra_'+str(j))]

   #print_poly_hex("v7v6        ", v7v6)
   #print_poly_hex("v5_partial  ", v5_partial)

   #############################################################################
   # Cycle 3
   #############################################################################
   cycle = 3

   #                                         |-----------------|
   #                                         |      W1*W1      |
   #                                         |-----------------|
   #                                         |-----------------|
   #  x2                                     |      W2*W0      |
   #                                         |-----------------|

   grid_cycle_3 = set_grid_5_cycle(cycle, sqr_in_seg, redundant_elements, 
                        nonredundant_elements, num_segments, bit_len, word_len)

   #                       |-----------------|
   #                       |      W2*W2      |
   #                       |-----------------|
   #                       |--------|
   #                       |   V5*  |
   #                       |--------|
   #                   |---|-----------------|
   #  x2               |   |      W3*W1      |
   #                   |---|-----------------|
   #     +
   #     ----------------------------------------------------------------------
   #                   |---|--------|--------|
   #                   |   |   V5   |   V4*  |
   #                   |---|--------|--------|

   add_prev_to_grid(grid_cycle_1, v5_partial, SEGMENT_ELEMENTS, 
                    SEGMENT_ELEMENTS, GRID_BIT_LEN)

   sub_totals_cycle_1 = compress_grid(grid_cycle_1, GRID_SIZE, 
                                      GRID_BIT_LEN, WORD_LEN)

   #print('C1 grid')
   #print_grid(grid_cycle_1, GRID_SIZE, 9)
   #print('C1 subtotal')
   #print_compressed_grid(sub_totals_cycle_1)

   v5v4_partial = (TWO_SEGMENTS)*[0]
   for j in range (TWO_SEGMENTS):
      v5v4_partial[j] = sub_totals_cycle_1[j]

   #for j in range (REDUNDANT_ELEMENTS + EXTRA_ELEMENTS):
   #   v5v4_partial_extra_elements[j] =  v5v4_partial[j + (SEGMENT_ELEMENTS*2)]
   #print_poly_hex("v5v4_partial_extra_elements", v5v4_partial_extra_elements)

   #print_poly_hex("v5v4_partial", v5v4_partial)

   #                                  |-----------------------------------|
   #                                  |              ...                  |
   # |---|--------|--------|       |-----------------------------------|  |
   # |   |   V7   |   V6   |  -->  |                                   |  |
   # |---|--------|--------|       |       Memory Lookup Tables        |--|
   #                               |               Upper               |
   #                               |-----------------------------------|

   v7v6_upper = [[0 for x in range (NONREDUNDANT_ELEMENTS)]
                  for y in range (TWO_SEGMENTS)]

   for i in range (TWO_SEGMENTS):
      v7v6_high     = (v7v6[i] >> LOOK_UP_WIDTH) & LUT_MASK
      v7v6_upper[i] = redLUT[i][v7v6_high]
      #print("v7v6 high   ", hex(v7v6_high))
      #print_poly_hex("v7v6 upper  ", v7v6_upper[i])

   #############################################################################
   # Cycle 4
   #############################################################################
   cycle = 4

   #                                                         |-----------------|
   #                                                         |      W0*W0      |
   #                                                         |-----------------|
   #                                                |-----------------|
   #  x2                                            |      W1*W0      |
   #                                                |-----------------|

   grid_cycle_4 = set_grid_5_cycle(cycle, sqr_in_seg, redundant_elements, 
                        nonredundant_elements, num_segments, bit_len, word_len)

   #                                |-----------------|
   #  x2                            |      W2*W1      |
   #                                |-----------------|
   #                                |--------|
   #                                |   V4*  |
   #                                |--------|
   #                            |---|-----------------|
   #  x2                        |   |      W3*W0      |
   #                            |---|-----------------|
   #     +
   #     ----------------------------------------------------------------------
   #                   |---|--------|--------|--------|
   #                   |   |   V5   |   V4   |   V3*  |
   #                   |---|--------|--------|--------|

   add_prev_to_grid(grid_cycle_2, v5v4_partial, SEGMENT_ELEMENTS, 
                    TWO_SEGMENTS, GRID_BIT_LEN)

   sub_totals_cycle_2 = compress_grid(grid_cycle_2, GRID_SIZE, 
                                      GRID_BIT_LEN, WORD_LEN)

   #print('C2 grid')
   #print_grid(grid_cycle_2, GRID_SIZE, 9)
   #print('C2 subtotal')
   #print_compressed_grid(sub_totals_cycle_2)

   v3_partial = SEGMENT_ELEMENTS*[0]
   for j in range (SEGMENT_ELEMENTS):
      v3_partial[j] = sub_totals_cycle_2[j]

   #print_poly_hex("v3_partial  ", v3_partial)

   v5v4 = (TWO_SEGMENTS)*[0]
   for j in range (TWO_SEGMENTS):
      v5v4[j] = sub_totals_cycle_2[j + SEGMENT_ELEMENTS]

   #print_poly_hex("v5v4        ", v5v4)

   #                                  |-----------------------------------|
   #                                  |              ...                  |
   # |---|--------|--------|       |-----------------------------------|  |
   # |   |   V7   |   V6   |  -->  |                                   |  |
   # |---|--------|--------|       |       Memory Lookup Tables        |--|
   #                               |               Lower               |
   #                               |-----------------------------------|

   v7v6_lower = [[0 for x in range (NONREDUNDANT_ELEMENTS)]
                  for y in range (TWO_SEGMENTS)]

   for i in range (TWO_SEGMENTS):
      v7v6_low      = v7v6[i] & LUT_MASK
      v7v6_lower[i] = redLUT[i][v7v6_low]

   #                                  |-----------------------------------|
   #                                  |                                   |
   #                                  |-----------------------------------|
   #                                                   ...
   #                                  |-----------------------------------|
   #     +                            |                                   |
   #                                  |-----------------------------------|
   #     ----------------------------------------------------------------------
   #                                  |-----------------------------------|
   #                                  |     Accumulation V7,V6 upper      |
   #                                  |-----------------------------------|

   # Running accumulation total
   #curr_accum = (NUM_ELEMENTS+EXTRA_ELEMENTS)*[0]
   curr_accum = (NUM_ELEMENTS)*[0]

   # Upper bits need to be shifted before accumulating
   for i in range (TWO_SEGMENTS):
      for j in range (NONREDUNDANT_ELEMENTS):
         curr_accum[j]   += (v7v6_upper[i][j] << LOOK_UP_WIDTH) & WORD_MASK
         curr_accum[j+1] += (v7v6_upper[i][j] >> LOOK_UP_WIDTH)

   #print_poly_hex("C4 pre accum", curr_accum)

   partial_reduction(curr_accum, 0, NUM_ELEMENTS, WORD_LEN)

   #print_poly_hex("C4 accum    ", curr_accum)

   #############################################################################
   # Cycle 5
   #############################################################################
   cycle = 5

   #                                         |-----------------|
   #                                         |      W1*W1      |
   #                                         |-----------------|
   #                                         |--------|
   #                                         |   V3*  |
   #                                         |--------|
   #                                         |-----------------|
   #  x2                                     |      W2*W0      |
   #                                         |-----------------|
   #     +
   #     ----------------------------------------------------------------------
   #                                     |---|--------|--------|
   #                                     |   |   V3   |   V2*  |
   #                                     |---|--------|--------|

   add_prev_to_grid(grid_cycle_3, v3_partial, SEGMENT_ELEMENTS, 
                    SEGMENT_ELEMENTS, GRID_BIT_LEN)

   sub_totals_cycle_3 = compress_grid(grid_cycle_3, GRID_SIZE, 
                                      GRID_BIT_LEN, WORD_LEN)

   #print('C3 grid')
   #print_grid(grid_cycle_3, GRID_SIZE, 9)
   #print('C3 subtotal')
   #print_compressed_grid(sub_totals_cycle_3)

   #v3 = (ONE_SEGMENT)*[0]
   v3 = (SEGMENT_ELEMENTS+REDUNDANT_ELEMENTS)*[0]
   for j in range (SEGMENT_ELEMENTS+REDUNDANT_ELEMENTS):
      v3[j] = sub_totals_cycle_3[j+SEGMENT_ELEMENTS]

   #print_poly_hex("v3          ", v3)

   v2_partial = SEGMENT_ELEMENTS*[0]
   for j in range (SEGMENT_ELEMENTS):
      v2_partial[j] = sub_totals_cycle_3[j]
   #print_poly_hex("v2_partial  ", v2_partial)

   # CONDITIONAL - only if overflow exists
   #                                  |-----------------------------------|
   #                                  |              ...                  |
   # |---|--------|--------|       |-----------------------------------|  |
   # |   |   V7   |   V6   |  -->  |                                   |  |
   # |---|--------|--------|       |       Memory Lookup Tables        |--|
   #                               |             Overflow              |
   #                               |-----------------------------------|

   v7v6_overflow = 0
   v7v6_over  = [[0 for x in range (NONREDUNDANT_ELEMENTS)]
                  for y in range (TWO_SEGMENTS)]

   for i in range (TWO_SEGMENTS):
      v7v6_top      = (v7v6[i] >> WORD_LEN) 
      v7v6_over[i]  = redLUT[i][v7v6_top]
      if (v7v6_top != 0):
         v7v6_overflow = 1

   # Do this cycle only if overflow does not exist
   #                                  |-----------------------------------|
   #                                  |              ...                  |
   # |---|--------|--------|       |-----------------------------------|  |
   # |   |   V5   |   V4   |  -->  |                                   |  |
   # |---|--------|--------|       |       Memory Lookup Tables        |--|
   #                               |               Upper               |
   #                               |-----------------------------------|

   v5v4_upper = [[0 for x in range (NONREDUNDANT_ELEMENTS)]
                  for y in range (TWO_SEGMENTS)]

   for i in range (TWO_SEGMENTS):
      v5v4_high     = (v5v4[i] >> LOOK_UP_WIDTH) & LUT_MASK
      v5v4_upper[i] = redLUT[i][v5v4_high + LUT_SIZE]

   #                                  |-----------------------------------|
   #                                  |     Accumulation V7,V6 upper      |
   #                                  |-----------------------------------|

   #                                  |-----------------------------------|
   #                                  |                                   |
   #                                  |-----------------------------------|
   #                                                   ...
   #                                  |-----------------------------------|
   #     +                            |                                   |
   #                                  |-----------------------------------|
   #     ----------------------------------------------------------------------
   #                                  |-----------------------------------|
   #                                  |   Accumulation V7,V6 upper/lower  |
   #                                  |-----------------------------------|

   for i in range (TWO_SEGMENTS):
      for j in range (NONREDUNDANT_ELEMENTS):
         curr_accum[j] += v7v6_lower[i][j]

   partial_reduction(curr_accum, 0, NUM_ELEMENTS, WORD_LEN)

   #print_poly_hex("C5 accum    ", curr_accum)

   #############################################################################
   # Cycle 6
   #############################################################################
   cycle = 6

   #                                                        |-----------------|
   #                                                        |      W0*W0      |
   #                                                        |-----------------|
   #                                               |-----------------|
   #  x2                                           |      W1*W0      |
   #                                               |-----------------|
   #                                               |--------|
   #                                               |   V2*  |
   #                                               |--------|
   #  +
   #  -------------------------------------------------------------------------
   #                                  |---|--------|--------|--------|--------|
   #                                  |   |   V3   |   V2   |   V1   |   V0   |
   #                                  |---|--------|--------|--------|--------|

   add_prev_to_grid(grid_cycle_4, v2_partial, (SEGMENT_ELEMENTS*2), 
                    SEGMENT_ELEMENTS, GRID_BIT_LEN)

   sub_totals_cycle_4 = compress_grid(grid_cycle_4, GRID_SIZE, 
                                      GRID_BIT_LEN, WORD_LEN)

   #print('C4 grid')
   #print_grid(grid_cycle_4, GRID_SIZE, 9)
   #print('C4 subtotal')
   #print_compressed_grid(sub_totals_cycle_4)

   v2v0 = (THREE_SEGMENTS)*[0]
   for j in range (THREE_SEGMENTS):
      v2v0[j] = sub_totals_cycle_4[j]

   #print_poly_hex("v2v0        ", v2v0)

   #                                  |-----------------------------------|
   #                                  |              ...                  |
   # |---|--------|--------|       |-----------------------------------|  |
   # |   |   V5   |   V4   |  -->  |                                   |  |
   # |---|--------|--------|       |       Memory Lookup Tables        |--|
   #                               |               Lower               |
   #                               |-----------------------------------|

   v5v4_lower = [[0 for x in range (NONREDUNDANT_ELEMENTS)]
                  for y in range (TWO_SEGMENTS)]
   for i in range (TWO_SEGMENTS):
      v5v4_low      = v5v4[i] & LUT_MASK
      v5v4_lower[i] = redLUT[i][v5v4_low + LUT_SIZE]

   # Either accumulate V5V4 upper of V7V6 overflow 

   #                                  |-----------------------------------|
   #                                  |   Accumulation V7,V6 upper/lower  |
   #                                  |-----------------------------------|
   #
   #                                  |-----------------------------------|
   #                                  |                                   |
   #                                  |-----------------------------------|
   #                                                   ...
   #                                  |-----------------------------------|
   #     +                            |                                   |
   #                                  |-----------------------------------|
   #     ----------------------------------------------------------------------
   #                                  |-----------------------------------|
   #                                  |   Accumulation V7,V6, V5,V4 upper |
   #                                  |-----------------------------------|

   if (v7v6_overflow != 0):
      #print("DOING OVERFLOW V7V6")
      for i in range (TWO_SEGMENTS):
         for j in range (NONREDUNDANT_ELEMENTS):
            curr_accum[j+1] += v7v6_over[i][j]

      partial_reduction(curr_accum, 0, NUM_ELEMENTS, WORD_LEN)

   for i in range (TWO_SEGMENTS):
      for j in range (NONREDUNDANT_ELEMENTS):
         curr_accum[j]   += (v5v4_upper[i][j] << LOOK_UP_WIDTH) & WORD_MASK
         curr_accum[j+1] += (v5v4_upper[i][j] >> LOOK_UP_WIDTH)

   partial_reduction(curr_accum, 0, NUM_ELEMENTS, WORD_LEN)

   #print_poly_hex("C6 accum    ", curr_accum)

   #############################################################################
   # Cycle 7
   #############################################################################
   cycle = 7

   # CONDITIONAL - only if overflow exists
   #                                  |-----------------------------------|
   #                                  |              ...                  |
   # |---|--------|--------|       |-----------------------------------|  |
   # |   |   V5   |   V4   |  -->  |                                   |  |
   # |---|--------|--------|       |       Memory Lookup Tables        |--|
   #                               |             Overflow              |
   #                               |-----------------------------------|

   v5v4_overflow = 0

   v5v4_over  = [[0 for x in range (NONREDUNDANT_ELEMENTS)]
                  for y in range (TWO_SEGMENTS)]

   for i in range (TWO_SEGMENTS):
      v5v4_top      = (v5v4[i] >> WORD_LEN) 
      v5v4_over[i]  = redLUT[i][v5v4_top + LUT_SIZE]
      if (v5v4_top != 0):
         v5v4_overflow = 1

   #                              |---|--------|--------|--------|--------|
   #                              |   |   V3   |   V2   |   V1   |   V0   |
   #                              |---|--------|--------|--------|--------|
   #
   #                                  |-----------------------------------|
   #                                  |   Accumulation V7,V6, V5,V4 upper |
   #                                  |-----------------------------------|
   #
   #                                  |-----------------------------------|
   #                                  |                                   |
   #                                  |-----------------------------------|
   #                                                   ...
   #                                  |-----------------------------------|
   #     +                            |                                   |
   #                                  |-----------------------------------|
   #     ----------------------------------------------------------------------
   #                                  |-----------------------------------|
   #                                  |     Accumulation V7,V6, V5,V4     |
   #                                  |-----------------------------------|

   for i in range (TWO_SEGMENTS):
      for j in range (NONREDUNDANT_ELEMENTS):
         curr_accum[j] += v5v4_lower[i][j]

   for i in range (THREE_SEGMENTS):
      curr_accum[i] += v2v0[i]

   #for i in range (ONE_SEGMENT):
   for i in range (SEGMENT_ELEMENTS+REDUNDANT_ELEMENTS):
      curr_accum[i+(SEGMENT_ELEMENTS*3)] += v3[i]

   partial_reduction(curr_accum, 0, NUM_ELEMENTS, WORD_LEN)

   #print_poly_hex("C7 accum    ", curr_accum)

   #############################################################################
   # Cycle 8
   #############################################################################
   cycle = 8

   if (v5v4_overflow != 0):
      #print("DOING OVERFLOW V5V4")
      for i in range (TWO_SEGMENTS):
         for j in range (NONREDUNDANT_ELEMENTS):
            curr_accum[j+1] += v5v4_over[i][j]

      partial_reduction(curr_accum, 0, NUM_ELEMENTS, WORD_LEN)

      #print_poly_hex("C8 accum    ", curr_accum)

   sqr_out = 0
   for i in range (NUM_ELEMENTS):
      sqr_out += (curr_accum[i] << (i * WORD_LEN))

   #print("sqr out     ", hex(sqr_out))
   #print("sqr out mod ", hex(sqr_out % mod_in))

   #return sqr_out % mod_in
   return sqr_out

################################################################################
# Generate reduction LUTs
################################################################################

def generate_reduction_luts(mod_in, nonredundant_elements, redundant_elements, 
                            num_segments, word_len):
   REDUNDANT_ELEMENTS    = redundant_elements
   NONREDUNDANT_ELEMENTS = nonredundant_elements
   NUM_SEGMENTS          = num_segments
   WORD_LEN              = word_len

   WORD_MASK             = (2**WORD_LEN) - 1
   LOOK_UP_WIDTH         = WORD_LEN // 2
   LUT_SIZE              = (2**LOOK_UP_WIDTH)
   SEGMENT_ELEMENTS      = (NONREDUNDANT_ELEMENTS // NUM_SEGMENTS)

   EXTRA_ELEMENTS        = 2;
   TWO_SEGMENTS          = (SEGMENT_ELEMENTS*2) + REDUNDANT_ELEMENTS + \
                           EXTRA_ELEMENTS

    #Generate tables in redLUT[z][y][x] where:
    # z - Number of memories
    # y - Reduction address taken from the squared result coefficients
    # x - Precomputed reduction polynomial

   redLUT = [[[0 for x in range (NONREDUNDANT_ELEMENTS)]
              for y in range (LUT_SIZE * 2)]
             for z in range (TWO_SEGMENTS)]

   #print("X Y X", NONREDUNDANT_ELEMENTS, (LUT_SIZE * 2), TWO_SEGMENTS)

   # Compute the reduction tables
   for i in range (TWO_SEGMENTS):
      # Polynomial degree offset for V7V6
      offset = (SEGMENT_ELEMENTS*2)

      # Compute base reduction value for the coefficient degree
      t_v7v6 = (2**((i + NONREDUNDANT_ELEMENTS + offset) * WORD_LEN)) % mod_in
      t_v5v4 = (2**((i + NONREDUNDANT_ELEMENTS) * WORD_LEN)) % mod_in

      # Each address represents a different value stored in the coefficient
      for j in range (LUT_SIZE):
         cur_v7v6 = (t_v7v6 * j) % mod_in
         cur_v5v4 = (t_v5v4 * j) % mod_in

         #print(i, hex(j), "cur_v7v6", hex(cur_v7v6))

         # Break the precomputed result into polynomial coefficients
         for k in range (NONREDUNDANT_ELEMENTS):
            redLUT[i][j][k] = cur_v7v6 & WORD_MASK
            cur_v7v6 = cur_v7v6 >> WORD_LEN

            redLUT[i][j + LUT_SIZE][k] = cur_v5v4 & WORD_MASK
            cur_v5v4 = cur_v5v4 >> WORD_LEN
      #print()

   return redLUT

################################################################################
# Comparison checking
################################################################################

def check(mod_sqr_in, mod_in, mod_sqr_out_to_check):
   expected = (sqr_in * sqr_in) % mod_in

   debug = 0;

   if ((expected != mod_sqr_out_to_check) | debug):
      print()
      print("Input:   ", hex(mod_sqr_in))
      print()
      print("Modulus: ", hex(mod_in))
      print("Modulus: ", mod_in)
      print()
      print("Expected:", hex(expected))
      print()
      print("Received:", hex(mod_sqr_out_to_check))
      print()

   if (expected != mod_sqr_out_to_check):
      return 0

   return 1

def checkLUTS(a, b, x, y, z):
   for i in range (x):
      for j in range (y):
         for k in range (z):
            if (a[k][j][i] != b[k][j][i]):
               print("FAILED", k, j, i, hex(a[k][j][i]), hex(b[k][j][i]))

################################################################################
# Testing loops
################################################################################

random.seed(0)

num_tests     = 10
tests_run     = 0
tests_failed  = 0

# Test Parameters
num_segments   = 4                    # Fixed
num_redundants = [1, 2]               # Number of extra redundant elements
nonredundants  = [8, 16, 32, 64, 128] # number of elements list
word_lens      = [4, 8, 16]           # bit length of each element

num_redundants = [2]
nonredundants  = [128]
word_lens      = [16]

for l in word_lens:
   for k in nonredundants:
      for j in num_redundants:
         #mod_in = 0xe3e70682c2094cac629f6fbed82c07cd
         #mod_in = (2**(k*l))-1
         mod_in = random.getrandbits(k*l)

         redLUT = generate_reduction_luts(mod_in, k, j, num_segments, l)
         #s_redLUT = precompute_reduction_tables()
         #checkLUTS(redLUT, s_redLUT, k, 2*(2**(l//2)), ((k//4)*2)+j)

         #sqr_in = 0xf728b4fa42485e3a0a5d2f346baa9455
         #sqr_in = random.getrandbits((k+j)*l)
         #sqr_in = (2**2048)-1
         #sqr_in = (2**((k+j)*l))-1
         sqr_in = random.getrandbits(k*l)

         stats = {}
         
         print("Testing num elements", k, "+", j, "with word len", l)
         for i in range (num_tests):
            tests_run += 1

            mod_sqr_out = modular_square(sqr_in, mod_in, redLUT, j, 
                                         k, num_segments, (l+1), l, stats)

            print('Statistics:')
            print(stats)

            check_mod_sqr_out = mod_sqr_out % mod_in

            result = check(sqr_in, mod_in, check_mod_sqr_out)

            if (result == 0):
               tests_failed += 1
               print("Failure parameters:", j, k, l)

            sqr_in = mod_sqr_out

print("Passed", tests_run-tests_failed, "out of", tests_run, "tests")

result_str = "FAILED" if (tests_failed > 0) else "PASSED"
print(result_str)

