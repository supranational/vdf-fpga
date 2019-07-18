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

#if defined(FPGA) || defined(SDX_PLATFORM)
#include <MSUSDAccel.hpp>
#elif defined(SIMPLE_SQ)
#include <verilated.h>
#include <MSUVerilator.hpp>
#else
#include <verilated.h>
#include <MSUVerilator.hpp>
#endif

#include <Squarer.hpp>

#ifndef MOD_LEN
#define MOD_LEN 1024
#endif
#ifndef MODULUS
#define MODULUS "302934307671667531413257853548643485645"
#endif


void print_usage() {
    printf("Usage: host [1e] -m modulus\n");
    printf("\n");
    printf("Options:\n");
    printf("  -1       Use libgmp rrandom (default urandom)\n");
    printf("  -e       Enable hw emulation mode\n");
    printf("  -q       Quiet\n");
    printf("  -i num   Set the number of test iterations to run\n");
    printf("  -f num   Set t_final\n");
    printf("  -t num   Number of modsqr iterations per intermediate value\n");
    printf("  -n num   Set the number of modulus bits\n");
    printf("  -s 0xnum Set the the starting sq_in (default random)\n");
    printf("\n");
    exit(0);
}

int main(int argc, char** argv, char** env) {

    mpz_t modulus, sq_in;
    mpz_inits(modulus, sq_in, NULL);

    mpz_set_str(modulus, MODULUS, 10);

    int test_iterations         = 1;
    uint64_t t_final            = 1;
    uint64_t intermediate_iters = 0;
    int mod_len                 = MOD_LEN;
    bool rrandom                = false;
    bool hw_emu                 = false;
    bool quiet                  = false;
    int opt;
    while((opt = getopt(argc, argv, "h1qi:f:t:m:s:n:u:e")) != -1) {
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
        case 'q':
            quiet = true;
            break;
        case 'i':
            test_iterations = atoi(optarg);
            break;
        case 'f':
            t_final = atol(optarg);
            break;
        case 't':
            intermediate_iters = atol(optarg);
            break;
        case 'n':
            mod_len = atoi(optarg);
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

#if defined(FPGA) || defined(SDX_PLATFORM)
    MSUSDAccel   device;
#else
    MSUVerilator device(argc, argv);
#endif    

#if defined(SIMPLE_SQ)
  #if defined(DIRECT_TB)
    Squarer *squarer = new SquarerSimpleDirect(mod_len, modulus);
  #else
    Squarer *squarer = new SquarerSimple(mod_len, modulus);
  #endif
#else
 #if defined(DIRECT_TB)
    Squarer *squarer = new SquarerOzturkDirect(mod_len, modulus);
  #else
    Squarer *squarer = new SquarerOzturk(mod_len, modulus);
  #endif
#endif
    
    MSU msu(device, mod_len, modulus);
    msu.set_quiet(quiet);
    
    device.init(&msu, squarer);
    device.set_quiet(quiet);

    device.reset();


    if(intermediate_iters == 0) {
        intermediate_iters = t_final;
    }

    int failures = 0;
    uint64_t t_start = 0;
    for(int test = 0; test < test_iterations; test++) {
        uint64_t iter = 0; 
        while(iter < t_final) {
            uint64_t run_t_final = intermediate_iters;
            if(run_t_final + iter > t_final) {
                run_t_final = t_final - iter;
            }

            if(mpz_cmp_ui(sq_in, 0) != 0) {
                failures += msu.run_fixed(t_start, run_t_final, 
                                          sq_in, hw_emu);
            } else {
                failures += msu.run_random(t_start, run_t_final, 
                                           rrandom, hw_emu);
            }

            iter += intermediate_iters;
            mpz_set(sq_in, msu.sq_out);

            printf("\n");
            if(failures > 0) {
                return(failures);
            }
            if(!hw_emu) {
                double ns_per_iter = ((double)msu.compute_time / 
                                      (double)run_t_final);
                gmp_printf("%lu %0.1lf ns/sq: %Zd\n", iter, ns_per_iter,
                           msu.sq_out);
            }
        }
    }
    if(failures == 0 && hw_emu) {
        printf("\nPASSED %ld iterations\n", test_iterations*(t_final-t_start));
    }

    return(failures);
}
