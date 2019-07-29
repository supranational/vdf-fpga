#!/usr/bin/python3

from Crypto.PublicKey import RSA
from random import getrandbits

# Competition is for 1024 bits
NUM_BITS       = 1024

NUM_ITERATIONS = 1000

# Rather than being random each time, we will provide randomly generated values
x = getrandbits(NUM_BITS)
N = RSA.generate(NUM_BITS).n

# t should be small for testing purposes.  
# For the final FPGA runs, t will be around 1 billion
t = NUM_ITERATIONS

# Iterative modular squaring t times
# This is the function that needs to be optimized on FPGA
for _ in range(t):
   x = (x * x) % N

# Final result is a 1024b value
h = x
print(h)
