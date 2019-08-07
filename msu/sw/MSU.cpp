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

#include <MSU.hpp>
#include <stdlib.h>
#include <fstream>
#include <string>
#include <time.h>

void bn_shl(mpz_t bn, int bits) {
    mpz_mul_2exp(bn, bn, bits);
}
void bn_shr(mpz_t bn, int bits) {
    mpz_fdiv_q_2exp(bn, bn, bits);
}
void bn_init_mask(mpz_t mask, int bits) {
   mpz_set_ui(mask, 1);
   mpz_mul_2exp(mask, mask, bits);
   mpz_sub_ui(mask, mask, 1);
}

// Start a nanosecond-resolution timer
struct timespec timer_start(){
    struct timespec start_time;
    clock_gettime(CLOCK_REALTIME, &start_time);
    return start_time;
}

// End a timer, returning nanoseconds elapsed as a long
long timer_end(struct timespec start_time){
    struct timespec end_time;
    clock_gettime(CLOCK_REALTIME, &end_time);
    long diffInNanos = (end_time.tv_sec - start_time.tv_sec) *
        (long)1e9 + (end_time.tv_nsec - start_time.tv_nsec);
    return diffInNanos;
}


MSU::MSU(MSUDevice &_d, int _mod_len, mpz_t _modulus)
    : device(_d) {
    unsigned long seed = 0;
    gmp_randinit_mt(rand_state);
    gmp_randseed_ui(rand_state, seed);

    mod_len                 = _mod_len;

    mpz_inits(sq_in, modulus, sq_out, NULL);
    mpz_set(modulus, _modulus);
    gmp_printf("Modulus is %Zd\n\n", modulus);
}

MSU::~MSU() {
    mpz_clears(sq_in, modulus, sq_out, NULL);
}

// Run a job using the provided sq_in starting value.
int MSU::run_fixed(uint64_t _t_start, uint64_t _t_final, mpz_t _sq_in,
                   bool check) {
    t_start = _t_start;
    t_final = _t_final;
    mpz_set(sq_in, _sq_in);
    compute_job();
    if(check) {
        return(check_job());
    }
    return 0;
}

// Run a job using a random sq_in starting value.
int MSU::run_random(uint64_t _t_start, uint64_t _t_final, bool rrandom,
                    bool check) {
    t_start = _t_start;
    t_final = _t_final;
    prepare_random_job(rrandom);
    compute_job();
    if(check) {
        return(check_job());
    }
    return 0;
}

// Generate a random starting input
void MSU::prepare_random_job(bool rrandom) {
    int num_rand_bits = mod_len;
    if(rrandom) {
        // Use a smaller bit size to avoid getting an input bigger than the
        // modulus
        mpz_rrandomb(sq_in, rand_state, num_rand_bits-2);
    } else {
        mpz_urandomb(sq_in, rand_state, num_rand_bits);
    }
    mpz_mod(sq_in, sq_in, modulus);
}

// Once the job parameters are configured compute_job will execute it on the
// target.
void MSU::compute_job() {
    struct timespec start_ts;
    start_ts = timer_start();
    
    //////////////////////////////////////////////////////////////////////
    // PREPROCESSING goes below this line (Montgomery conversion, etc)
    //

    // Perform the computation
    device.compute_job(t_start, t_final, sq_in, sq_out);

    //
    // POSTPROCESSING goes above this line (Montgomery conversion, etc)
    //////////////////////////////////////////////////////////////////////

    compute_time = timer_end(start_ts);

    if(!quiet) {
        gmp_printf("sq_out is 0x%Zx\n", sq_out);
    }
}

// Check the result by comparing it to the expected value as computed by
// software.
int MSU::check_job() {
    mpz_t expected;
    mpz_inits(expected, NULL);

    mpz_set(expected, sq_in);
    for(uint64_t i = t_start; i < t_final; i++) {
        mpz_powm_ui(expected, expected, 2, modulus);
        //gmp_printf("sq_in^2 is 0x%Zx\n", expected);
    }       

    if(!quiet) {
        gmp_printf("sq_in    is 0x%Zx\n", sq_in);
        gmp_printf("expected is 0x%Zx\n", expected);
        gmp_printf("actual   is 0x%Zx\n", sq_out);
    }

    // Check product
    int failures = 0;
    if (mpz_cmp(expected, sq_out) != 0) {
        printf("MISMATCH found - test Failed!\n");
        failures++;
    }
    if(failures == 0) {
        printf("MATCH!");
    }
        
    mpz_clears(expected, NULL);

    return(failures);
}

