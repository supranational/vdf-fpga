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

MOD_LEN = 1024
M = None

# Set to 50k for final regression runs
T_FINAL = 1000

gen_msuconfig = False

try:
   opts, args = getopt.getopt(sys.argv[1:],"hcM:s:", ["modulus=", "size="])
except getopt.GetoptError:
   print ('gen_test.py -M <modulus> [-c]')
   sys.exit(2)

for opt, arg in opts:
   if opt == '-h':
      print ('gen_test.py -M <modulus> [-c]')
      sys.exit()
   elif opt in ("-s", "--size"):
      MOD_LEN = int(arg)
   elif opt in ("-M", "--modulus"):
      M = int(arg)
   elif opt == "-c":
      gen_msuconfig = True

if MOD_LEN == 128 and M == None:
   M = 302934307671667531413257853548643485645

if MOD_LEN == 1024 and M == None:
   # For the Ozturk design this modulus must match what is found in modulus.mk
   # since reduction LUTs have to be generated ahead of time.
   MOD_LEN == 1024
   M = 124066695684124741398798927404814432744698427125735684128131855064976895337309138910015071214657674309443149407457493434579063840841220334555160125016331040933690674569571217337630239191517205721310197608387239846364360850220896772964978569683229449266819903414117058030106528073928633017118689826625594484331

print("MOD_LEN = %d" % MOD_LEN)
print("MODULUS = %d" % M)
print(" bitlen = %d" % (M.bit_length()))

f = open('test.txt', 'w')

sq_in = 2
f.write("%x\n" % sq_in)

def sqr(t_start, t_final, incr, sq_in):
    for i in range(t_start+incr, t_final+1, incr):
        for j in range(incr):
            sq_in = (sq_in * sq_in) % M
        
        f.write("%d, %x\n" % (i, sq_in))
    return(i, sq_in)

(t_curr, sq_in) = sqr(0, 10, 1, sq_in)
(t_curr, sq_in) = sqr(10, T_FINAL, 10, sq_in)

f.close()

if gen_msuconfig:
    f = open('msu.srcs/msuconfig.vh', 'w')
    f.write("`define SIMPLE_SQ 1\n")
    f.write("`define SQ_IN_BITS_DEF %d\n" % (MOD_LEN))
    f.write("`define SQ_OUT_BITS_DEF %d\n" % (MOD_LEN))
    f.write("`define MOD_LEN_DEF %d\n" % (MOD_LEN))
    f.write("`define MODULUS_DEF %d'h%x\n" % (MOD_LEN, M))
    f.close()

