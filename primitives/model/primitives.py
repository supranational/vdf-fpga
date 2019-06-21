#
#  Copyright 2019 Supranational, LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

def int_to_bits(x, bit_len):
   return [x >> i & 1 for i in range(0, bit_len)]

def bits_to_int(x):
   y = 0
   for i, b in enumerate(x):
      y = (b << i) | y
   return y

# Full Adder
def fa(A, B, Cin):
   S    = A ^ B ^ Cin
   Cout = (A & B) | (Cin & (A ^B))
   return Cout, S

# Carry Save Adder
def csa(A, B, Cin, bit_len):
   Cout = bit_len*[0]
   S    = bit_len*[0]
   for i in range(bit_len):
      Cout[i], S[i] = fa(A[i], B[i], Cin[i])
   return Cout, S

# One level of the compressor tree
def csa_level(terms, bit_len):
   num_results  = len(terms)//3

   result_terms = []

   # Feed three consecutive terms to a CSA
   for i in range(2, len(terms), 3):
      cout, s  = csa(terms[i-2], terms[i-1], terms[i], bit_len)
      # Need to shift carry 1 bit
      cout.insert(0,0)
      s.append(0)
      result_terms.append(cout)
      result_terms.append(s)

   # Push any leftover terms not feed to a CSA to the next level
   for i in range(len(terms)%3):
      temp_term = terms[(len(terms)-1)-i]
      temp_term.append(0)
      result_terms.append(temp_term)

   return result_terms

# 3:2 compressor tree
def compressor_tree(terms, bit_len):
   if (len(terms) == 3):
      cout, s          = csa(terms[0], terms[1], terms[2], bit_len)
      cout.insert(0,0)
      s.append(0)
   else:
      next_level_terms = csa_level(terms, bit_len)
      cout, s          = compressor_tree(next_level_terms, bit_len+1)

   return cout, s

# Multiplier
def multiplier(A, B):
   P = A * B
   return P

def multiply(A, B, NUM_ELEMENTS, COL_BIT_LEN, WORD_LEN):
   mul_result = (NUM_ELEMENTS*NUM_ELEMENTS)*[0]
   for i in range (NUM_ELEMENTS):
      for j in range(NUM_ELEMENTS):
         mul_result[(NUM_ELEMENTS*i)+j] = multiplier(A[i], B[j])

   # grid[col][row]
   grid = [[0 for x in range(NUM_ELEMENTS*2)] for y in range(NUM_ELEMENTS*2)]
   for i in range (NUM_ELEMENTS):
      for j in range(NUM_ELEMENTS):
         grid[i+j][2*i]       = mul_result[(NUM_ELEMENTS*i)+j] & \
                                (pow(2,WORD_LEN)-1)
         grid[i+j+1][(2*i)+1] = (mul_result[(NUM_ELEMENTS*i)+j] >> WORD_LEN) & \
                                (pow(2,COL_BIT_LEN)-1)

   cout = (NUM_ELEMENTS*2)*[0]
   s    = (NUM_ELEMENTS*2)*[0]

   cout[0]                  = 0
   cout[(NUM_ELEMENTS*2)-1] = 0

   s[0]                     = grid[0][0]
   s[(NUM_ELEMENTS*2)-1]    = grid[(NUM_ELEMENTS*2)-1][(NUM_ELEMENTS*2)-1]

   for i in range (1, (NUM_ELEMENTS*2)-1):
      grid_bits = []
      for g in grid[i]:
         grid_bits.append(int_to_bits(g, COL_BIT_LEN))

      result  = compressor_tree(grid_bits, COL_BIT_LEN)
      cout[i] = bits_to_int(result[0])
      s[i]    = bits_to_int(result[1])

   return cout, s

