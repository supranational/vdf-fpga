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

import sys
import getopt

################################################################################
# Parameters to set
################################################################################
REDUNDANT_ELEMENTS    = 2
NONREDUNDANT_ELEMENTS = 8
NUM_SEGMENTS          = 4
WORD_LEN              = 16
EXTRA_ELEMENTS        = 2

# TODO - we probably don't need these hardcoded values anymore
if (NONREDUNDANT_ELEMENTS == 128):
   M = 6314466083072888893799357126131292332363298818330841375588990772701957128924885547308446055753206513618346628848948088663500368480396588171361987660521897267810162280557475393838308261759713218926668611776954526391570120690939973680089721274464666423319187806830552067951253070082020241246233982410737753705127344494169501180975241890667963858754856319805507273709904397119733614666701543905360152543373982524579313575317653646331989064651402133985265800341991903982192844710212464887459388853582070318084289023209710907032396934919962778995323320184064522476463966355937367009369212758092086293198727008292431243681
else:
   M = 302934307671667531413257853548643485645

try:
   opts, args = getopt.getopt(sys.argv[1:],"hM:r:n:w:",           \
                              ["modulus=","redundant=",           \
                               "nonredundant=", "wordlen="])
except getopt.GetoptError:
   print ('gen_reduction_lut.py -M <modulus> -r <num redundant>', \
         '-nr <num nonredundant> -wl <word length>')
   sys.exit(2)

for opt, arg in opts:
   if opt == '-h':
      print ('gen_reduction_lut.py -M <modulus> -r <num redundant>', \
            '-nr <num nonredundant> -wl <word length>')
      sys.exit()
   elif opt in ("-M", "--modulus"):
      M = int(arg)
   elif opt in ("-r", "--redundant"):
      REDUNDANT_ELEMENTS = int(arg)
   elif opt in ("-n", "--nonredundant"):
      NONREDUNDANT_ELEMENTS = int(arg)
   elif opt in ("-w", "--wordlen"):
      WORD_LEN = int(arg)

print ()
print ('Parameter Values')
print ('---------------------')
print ('REDUNDANT_ELEMENTS   ', REDUNDANT_ELEMENTS)
print ('NONREDUNDANT_ELEMENTS', NONREDUNDANT_ELEMENTS)
print ('WORD_LEN             ', WORD_LEN)
print ('NUM_SEGMENTS         ', NUM_SEGMENTS)
print ('EXTRA_ELEMENTS       ', EXTRA_ELEMENTS)
print ('M                    ', hex(M))
print ()

################################################################################
# Calculated parameters
################################################################################
SEGMENT_ELEMENTS      = (NONREDUNDANT_ELEMENTS // NUM_SEGMENTS)
LUT_NUM_ELEMENTS      = REDUNDANT_ELEMENTS + (SEGMENT_ELEMENTS*2) + \
                        EXTRA_ELEMENTS
LOOK_UP_WIDTH         = WORD_LEN // 2
LUT_SIZE              = 2**LOOK_UP_WIDTH
LUT_WIDTH             = WORD_LEN * NONREDUNDANT_ELEMENTS;

################################################################################
# Compute the reduction tables
################################################################################

print ('Creating', LUT_NUM_ELEMENTS, 'files')
print ('reduction_lut_{0:03d}.dat'.format(0))
print ('         ...          ')
print ('reduction_lut_{0:03d}.dat'.format(LUT_NUM_ELEMENTS-1))

for i in range (LUT_NUM_ELEMENTS):
   Filename = list('reduction_lut_{0:03d}.dat'.format(i))
   f = open(''.join(Filename), 'w')

   # Polynomial degree offset for V7V6
   offset = (SEGMENT_ELEMENTS*2)

   # Compute base reduction value for the coefficient degree
   t_v7v6 = (2**((i + NONREDUNDANT_ELEMENTS + offset) * WORD_LEN)) % M
   t_v5v4 = (2**((i + NONREDUNDANT_ELEMENTS) * WORD_LEN)) % M

   # Each address represents a different value stored in the coefficient
   for j in range (LUT_SIZE):
      cur_v7v6 = (t_v7v6 * j) % M
      f.write(hex(cur_v7v6)[2:].zfill(LUT_WIDTH // 4))
      f.write('\n')

   for j in range (LUT_SIZE):
      cur_v5v4 = (t_v5v4 * j) % M
      f.write(hex(cur_v5v4)[2:].zfill(LUT_WIDTH // 4))
      f.write('\n')

   f.close()

################################################################################
# Generate RTL to read in files
################################################################################
# This should not really be necessary 
# Required since parameterizing RTL to read in data was failing synthesis

f = open('reduction_lut.sv', 'w')

top = \
'''/*******************************************************************************
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
*******************************************************************************/

module reduction_lut
   #(
     parameter int REDUNDANT_ELEMENTS    = 2,
     parameter int NONREDUNDANT_ELEMENTS = 8,
     parameter int NUM_SEGMENTS          = 4,
     parameter int WORD_LEN              = 16,
     parameter int BIT_LEN               = 17,

     parameter int NUM_ELEMENTS          = REDUNDANT_ELEMENTS+
                                           NONREDUNDANT_ELEMENTS,
     parameter int LOOK_UP_WIDTH         = int\'(WORD_LEN / 2),
     parameter int SEGMENT_ELEMENTS      = int\'(NONREDUNDANT_ELEMENTS /
                                                 NUM_SEGMENTS),
     parameter int EXTRA_ELEMENTS        = 2,
     parameter int LUT_NUM_ELEMENTS      = REDUNDANT_ELEMENTS+EXTRA_ELEMENTS+
                                           (SEGMENT_ELEMENTS*2)

    )
   (
    input  logic                    clk,
    input  logic [LOOK_UP_WIDTH:0]  lut_addr[LUT_NUM_ELEMENTS],
    input  logic                    shift_high,
    input  logic                    shift_overflow,
    output logic [BIT_LEN-1:0]      lut_data[NUM_ELEMENTS][LUT_NUM_ELEMENTS]
   );

   // There is twice as many entries due to low and high values
   localparam int NUM_LUT_ENTRIES   = 2**(LOOK_UP_WIDTH+1);
   localparam int LUT_WIDTH         = WORD_LEN * NONREDUNDANT_ELEMENTS;
   localparam int FULL_WIDTH        = WORD_LEN * NUM_ELEMENTS;

   logic [FULL_WIDTH-1:0] lut_read_data[LUT_NUM_ELEMENTS];
   logic [BIT_LEN-1:0]    lut_output[NUM_ELEMENTS][LUT_NUM_ELEMENTS];

'''
f.write(top)

block_str = '   (* rom_style = "block" *) logic [LUT_WIDTH-1:0] lut_{0:03d}[NUM_LUT_ENTRIES];\n'

for i in range (LUT_NUM_ELEMENTS):
   f.write(block_str.format(i))

read_str = '      $readmemh("reduction_lut_{0:03d}.dat", lut_{0:03d});\n'

f.write('\n   initial begin\n')
for i in range (LUT_NUM_ELEMENTS):
   f.write(read_str.format(i))
f.write('   end\n')

assign_str = '      lut_read_data[{0:d}] = {{{{FULL_WIDTH-LUT_WIDTH{{1\'b0}}}},\n\
                           lut_{0:03d}[lut_addr[{0:d}]][LUT_WIDTH-1:0]}};\n'
f.write('\n   always_comb begin\n')
for i in range (LUT_NUM_ELEMENTS):
   f.write(assign_str.format(i))
f.write('   end\n')

bottom = \
'''
   always_comb begin
      for (int k=0; k<LUT_NUM_ELEMENTS; k=k+1) begin
         for (int l=0; l<NUM_ELEMENTS; l=l+1) begin
            // TODO - should be unique, fails when in reset
            if (shift_high) begin
               lut_output[l][k][BIT_LEN-1:LOOK_UP_WIDTH] =
                  {{(BIT_LEN-WORD_LEN){1\'b0}},
                   lut_read_data[k][(l*WORD_LEN)+:LOOK_UP_WIDTH]};

               if (l == 0) begin
                  lut_output[l][k][LOOK_UP_WIDTH-1:0] = \'0;
               end
               else begin
                  lut_output[l][k][LOOK_UP_WIDTH-1:0] =
                lut_read_data[k][((l-1)*WORD_LEN)+LOOK_UP_WIDTH+:LOOK_UP_WIDTH];
               end
            end
            else if (shift_overflow) begin
               if (l == 0) begin
                  lut_output[l][k] = \'0;
               end
               else begin
                  lut_output[l][k] =
                     {{(BIT_LEN-WORD_LEN){1\'b0}},
                      lut_read_data[k][((l-1)*WORD_LEN)+:WORD_LEN]};
               end
            end
            else begin
               lut_output[l][k] =
                  {{(BIT_LEN-WORD_LEN){1\'b0}},
                   lut_read_data[k][(l*WORD_LEN)+:WORD_LEN]};
            end
         end
      end
   end

   // Need above loops in combo block for Verilator to process
   always_ff @(posedge clk) begin
      lut_data <= lut_output;
   end
endmodule
'''

f.write(bottom)
f.close()
