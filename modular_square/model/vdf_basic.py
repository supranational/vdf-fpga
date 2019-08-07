#!/usr/bin/python3

from random import getrandbits

# Competition is for 1024 bits
NUM_BITS       = 1024

NUM_ITERATIONS = 1000

# Rather than being random each time, we will provide randomly generated values
x = getrandbits(NUM_BITS)
N = 124066695684124741398798927404814432744698427125735684128131855064976895337309138910015071214657674309443149407457493434579063840841220334555160125016331040933690674569571217337630239191517205721310197608387239846364360850220896772964978569683229449266819903414117058030106528073928633017118689826625594484331

# t should be small for testing purposes.  
# For the final FPGA runs, t will be 2^30
t = NUM_ITERATIONS

# Iterative modular squaring t times
# This is the function that needs to be optimized on FPGA
for _ in range(t):
   x = (x * x) % N

# Final result is a 1024b value
h = x
print(h)
