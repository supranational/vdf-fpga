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

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <MSU.hpp>

#ifdef FPGA
#include <MSUSDAccel.hpp>
#else
#include <verilated.h>
#include <MSUVerilator.hpp>
#endif

void print_usage() {
    printf("Usage: host [1e] -m modulus\n");
    printf("\n");
    printf("Options:\n");
    printf("  -1       Use libgmp rrandom (default urandom)\n");
    printf("  -e       Enable hw emulation mode\n");
    printf("  -i num   Set the number of tests to run\n");
    printf("  -f num   Set t_final\n");
    printf("  -w num   Set word length, in bits (default 16)\n");
    printf("  -r num   Set the number of redundant elements\n");
    printf("  -n num   Set the number of nonredundant elements\n");
    printf("  -s 0xnum Set the the starting sq_in (default random)\n");
    printf("\n");
    exit(0);
}

int main(int argc, char** argv, char** env) {

    mpz_t modulus, sq_in;
    mpz_inits(modulus, sq_in, NULL);

    int iterations            = 2;
    uint64_t t_final          = 1;
    int word_len              = 16;
    int redundant_elements    = 2;
    int nonredundant_elements = 8;
    bool rrandom              = false;
    bool hw_emu               = false;
    int opt;
    while((opt = getopt(argc, argv, "h1i:f:m:s:w:r:n:e")) != -1) {
        switch(opt) {
        case 'h':
            print_usage();
            break;
        case '1':
            rrandom = true;
            break;
        case 'e':
            hw_emu = true;
            break;
        case 'i':
            iterations = atoi(optarg);
            break;
        case 'f':
            t_final = atoi(optarg);
            break;
        case 'w':
            word_len = atoi(optarg);
            break;
        case 'r':
            redundant_elements = atoi(optarg);
            break;
        case 'n':
            nonredundant_elements = atoi(optarg);
            break;
        case 's':
            if(mpz_set_str(sq_in, optarg+2, 16) != 0) {
                printf("Failed to parse sq_in %s!\n", optarg);
                exit(1);
            }
            break;
        case 'm':
            if(mpz_set_str(modulus, optarg, 10) != 0) {
                printf("Failed to parse modulus %s!\n", optarg);
                exit(1);
            }
            break;
        }
    };
    if(mpz_cmp_ui(modulus, 0) == 0) {
        printf("ERROR: must provide a modulus with -m\n");
        exit(1);
    }

    if(rrandom) {
        printf("Enabling rrandom testing\n");
    }
    if(hw_emu) {
        printf("Enabling hardware emulation mode\n");
    }
    
#ifdef FPGA
    MSUSDAccel   device;
#else
    MSUVerilator device(argc, argv);
#endif
    MSU msu(device, word_len,
            redundant_elements, nonredundant_elements, modulus);

    device.reset();

    int failures = 0;
    uint64_t t_start = 0;
    for(int i = 0; i < iterations; i++) {
        if(mpz_cmp_ui(sq_in, 0) != 0) {
            failures += msu.run_fixed(t_start, t_final, sq_in);
        } else {
            failures += msu.run_random(t_start, t_final, rrandom);
        }
        printf("\n");
        if(failures > 0) {
            return(failures);
        }
    }
    if(failures == 0) {
        printf("\nPASSED %ld iterations\n", iterations*(t_final-t_start));
    }

    return(failures);
}
