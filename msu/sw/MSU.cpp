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


MSU::MSU(MSUDevice &_d, int _word_len,
        int _redundant_elements, int _nonredundant_elements, mpz_t _modulus)
    : device(_d) {
    unsigned long seed = 0;
    gmp_randinit_mt(rand_state);
    gmp_randseed_ui(rand_state, seed);

    word_len              = _word_len;
    bit_len               = _word_len+1;
    redundant_elements    = _redundant_elements;
    nonredundant_elements = _nonredundant_elements;

    num_elements  = redundant_elements + nonredundant_elements;
    msu_words_in  = (T_LEN/MSU_WORD_LEN*2 + (nonredundant_elements+1)/2);
    msu_words_out = (T_LEN/MSU_WORD_LEN + num_elements);

    mpz_inits(A, modulus, msu_in, msu_out, NULL);
    mpz_set(modulus, _modulus);
    gmp_printf("Modulus is %Zd\n\n", modulus);

    device.init(msu_words_in, msu_words_out);
}

MSU::~MSU() {
    mpz_clears(A, modulus, msu_in, msu_out, NULL);
}

int MSU::run_fixed(uint64_t _t_start, uint64_t _t_final, mpz_t sq_in) {
    t_start = _t_start;
    t_final = _t_final;
    mpz_set(A, sq_in);
    pack_to_msu(msu_in, t_start, t_final, A);
    compute_job();
    return(check_job()); 
}

int MSU::run_random(uint64_t _t_start, uint64_t _t_final, bool rrandom) {
    t_start = _t_start;
    t_final = _t_final;
    prepare_random_job(rrandom);
    pack_to_msu(msu_in, t_start, t_final, A);
    compute_job();
    return(check_job()); 
}

void MSU::prepare_random_job(bool rrandom) {
    int num_rand_bits = nonredundant_elements * word_len;
    if(rrandom) {
        // One less bit to avoid getting larger than the modulus
        //printf("Generate rrandom %d bits\n", num_rand_bits-2);
        mpz_rrandomb(A, rand_state, num_rand_bits-2);
    } else {
        //printf("Generate urandom %d bits\n", num_rand_bits);
        mpz_urandomb(A, rand_state, num_rand_bits);
    }
    //gmp_printf("A is 0x%Zx\n", A);
    mpz_mod(A, A, modulus);
    //gmp_printf("A is 0x%Zx\n", A);
}

void MSU::compute_job() {
    device.compute_job(msu_out, msu_in);
}

int MSU::check_job() {
    mpz_t expected, actual;
    mpz_inits(expected, actual, NULL);
    compute_expected(expected);

    uint64_t t_final_result;
    unpack_from_msu(actual, &t_final_result, msu_out);

    gmp_printf("sq_in    is 0x%Zx\n", A);
    gmp_printf("expected is 0x%Zx\n", expected);
    gmp_printf("actual   is 0x%Zx\n", actual);

    // Check t_final output
    int failures = 0;
    if(t_final_result != t_final) {
        printf("MISMATCH found in t_final - test Failed!\n");
        printf("Expected: %lu\n", t_final);
        printf("Received: %lu\n", t_final_result);
        failures++;
    }
    // Check product
    if (mpz_cmp(expected, actual) != 0) {
        printf("MISMATCH found - test Failed!\n");
        failures++;
    }
    if(failures == 0) {
        printf("MATCH!");
    }
        
    mpz_clears(expected, actual, NULL);

    return(failures);
}
    
void MSU::pack_to_msu(mpz_t msu_in,
                      uint64_t t_start, uint64_t t_final, mpz_t A) {
    mpz_set(msu_in, A);
        
    // t_final
    bn_shl(msu_in, T_LEN);
    mpz_add_ui(msu_in, msu_in, t_final);
        
    // t_start
    bn_shl(msu_in, T_LEN);
    mpz_add_ui(msu_in, msu_in, t_start);
}

void MSU::unpack_from_msu(mpz_t product,
                          uint64_t *t_final, mpz_t msu_out) {
    *t_final = mpz_get_ui(msu_out);
    bn_shr(msu_out, T_LEN);

    // Reduce the polynomial from redundant form
    reduce_polynomial(product, msu_out, MSU_WORD_LEN);
}

void MSU::compute_expected(mpz_t expected) {
    mpz_set(expected, A);
    for(uint64_t i = t_start; i < t_final; i++) {
        mpz_powm_ui(expected, expected, 2, modulus);
        //gmp_printf("A^2 is 0x%Zx\n", expected);
    }       
}

void MSU::reduce_polynomial(mpz_t result,
                            mpz_t poly, int padded_word_len) {
    uint64_t mask = (1ULL<<padded_word_len)-1;
        
    // Combine all of the coefficients
    mpz_t tmp;
    mpz_init(tmp);
    mpz_set_ui(result, 0);
    int count = 0;
    while(mpz_cmp_ui(poly, 0)) {
        uint64_t coeff = mpz_get_ui(poly);
        coeff &= mask;
        bn_shr(poly, padded_word_len);
            
        mpz_set_ui(tmp, coeff);
        bn_shl(tmp, word_len*count);
        mpz_add(result, result, tmp);
        count++;
    }
    mpz_clear(tmp);

    // Reduce mod M
    mpz_mod(result, result, modulus);
    //gmp_printf("MSU result is 0x%Zx\n", result);
}
