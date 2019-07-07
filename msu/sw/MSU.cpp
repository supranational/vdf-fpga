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



MSU::MSU(MSUDevice &_d, int _word_len,
         int _redundant_elements, int _nonredundant_elements,
         int _num_urams, mpz_t _modulus)
    : device(_d) {
    unsigned long seed = 0;
    gmp_randinit_mt(rand_state);
    gmp_randseed_ui(rand_state, seed);

    word_len                = _word_len;
    bit_len                 = _word_len+1;
    redundant_elements      = _redundant_elements;
    nonredundant_elements   = _nonredundant_elements;
    num_urams               = _num_urams;

    int segment_elements    = nonredundant_elements / NUM_SEGMENTS;
    int lut_num_elements    = (redundant_elements+EXTRA_ELEMENTS+
                                 segment_elements*2);

    if(num_urams > lut_num_elements) {
        printf("ERROR: num_urams %d > lut_num_elements %d\n",
               num_urams, lut_num_elements);
        exit(1);
    }
        
    uint64_t num_lut_entries = 1ULL << (word_len/2+1);
    reduction_rows_per_table = num_lut_entries;
    reduction_rows           = num_urams * reduction_rows_per_table;
    reduction_xfers_per_row  = nonredundant_elements*word_len/MSU_WORD_LEN;
    reduction_xfers          = reduction_xfers_per_row*reduction_rows;

    // printf("num_urams               = %d\n", num_urams);
    // printf("reduction_rows_per_table= %lu\n", reduction_rows_per_table);
    // printf("reduction_rows          = %lu\n", reduction_rows);
    // printf("reduction_xfers_per_row = %lu\n", reduction_xfers_per_row); 
    // printf("reduction_xfers         = %lu\n", reduction_xfers);

    num_elements  = redundant_elements + nonredundant_elements;
    msu_words_in  = (T_LEN/MSU_WORD_LEN*2 + (nonredundant_elements+1)/2);
    msu_words_out = (T_LEN/MSU_WORD_LEN + num_elements);

    mpz_inits(A, modulus, msu_in, msu_out, reduced_out, NULL);
    mpz_set(modulus, _modulus);
    gmp_printf("Modulus is %Zd\n\n", modulus);

    device.init(msu_words_in, msu_words_out);
}

MSU::~MSU() {
    mpz_clears(A, modulus, msu_in, msu_out, reduced_out, NULL);
}

void MSU::load_reduction_tables(const char *path) {
    char filename[255];
    mpz_t red_in;
    mpz_init(red_in);
    
    device.reduction_we(true);

    for(int table = 0; table < num_urams; table++) {
        printf("Writing reduction table %d..\n", table);
        
        sprintf(filename, "%s/reduction_lut_%03d.dat", path, table);
        std::ifstream infile(filename);
        if(!infile.is_open()) {
            printf("Could not open file %s for reading\n", filename);
            exit(1);
        }
        std::string line;
        
        for(unsigned i = 0; i < reduction_rows_per_table; i++) {
            std::getline(infile, line);
            mpz_set_str(red_in, line.c_str(), 16);
            
            //if(table == num_urams-1 && i > reduction_rows_per_table-4) {
            //gmp_printf("red_in[%d][%d] is 0x%Zx\n", table, i, red_in);
            //}
            device.reduction_write(red_in, reduction_xfers_per_row);
        }
    }
    // Let the data clock through
    for(int i = 0; i < 1000; i++) {
        device.clock_cycle();
    }
    device.reduction_we(false);
    printf("Done writing tables\n");

    for(int i = 0; i < 10; i++) {
        device.clock_cycle();
    }
    
    mpz_clear(red_in);
}

int MSU::run_fixed(uint64_t _t_start, uint64_t _t_final, mpz_t sq_in,
                   bool check) {
    t_start = _t_start;
    t_final = _t_final;
    mpz_set(A, sq_in);
    pack_to_msu(msu_in, t_start, t_final, A);
    compute_job();
    if(check) {
        return(check_job());
    }
    return 0;
}

int MSU::run_random(uint64_t _t_start, uint64_t _t_final, bool rrandom,
                    bool check) {
    t_start = _t_start;
    t_final = _t_final;
    prepare_random_job(rrandom);
    pack_to_msu(msu_in, t_start, t_final, A);
    compute_job();
    if(check) {
        return(check_job());
    }
    return 0;
}

void MSU::prepare_random_job(bool rrandom) {
    int num_rand_bits = nonredundant_elements * word_len;
    if(rrandom) {
        // Use a smaller bit size to avoid getting an input bigger than the
        // modulus
        mpz_rrandomb(A, rand_state, num_rand_bits-2);
    } else {
        mpz_urandomb(A, rand_state, num_rand_bits);
    }
    mpz_mod(A, A, modulus);
}

void MSU::compute_job() {
    struct timespec start_ts;
    start_ts = timer_start();
    device.compute_job(msu_out, msu_in);
    compute_time = timer_end(start_ts);

    unpack_from_msu(reduced_out, &t_final_out, msu_out);
    if(!quiet) {
        gmp_printf("reduced_out is 0x%Zx\n", reduced_out);
    }
}

int MSU::check_job() {
    mpz_t expected;
    mpz_inits(expected, NULL);
    compute_expected(expected);

    if(!quiet) {
        gmp_printf("sq_in    is 0x%Zx\n", A);
        gmp_printf("expected is 0x%Zx\n", expected);
        gmp_printf("actual   is 0x%Zx\n", reduced_out);
    }

    // Check t_final output
    int failures = 0;
    if(t_final_out != t_final) {
        printf("MISMATCH found in t_final - test Failed!\n");
        printf("Expected: %lu\n", t_final);
        printf("Received: %lu\n", t_final_out);
        failures++;
    }
    // Check product
    if (mpz_cmp(expected, reduced_out) != 0) {
        printf("MISMATCH found - test Failed!\n");
        failures++;
    }
    if(failures == 0) {
        printf("MATCH!");
    }
        
    mpz_clears(expected, NULL);

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
