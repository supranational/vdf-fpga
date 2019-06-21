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

#ifndef _MSU_LIB_H_
#define _MSU_LIB_H_

#include <gmp.h>
#include <stdint.h>

#define T_LEN                 64

#define MSU_BYTES_PER_WORD    4
#define MSU_WORD_LEN          (MSU_BYTES_PER_WORD*8)

// Use to define size of word on cpp side (1,2,4,8) depending on bit_len
#define BN_BUFFER_SIZE        4  // top.sv BIT_LEN = 17-32

// Use to create offset when using larger words for bit_len
// Such as when bit_len in top.sv is 17b and is 16b here, offset is 16
#define BN_BUFFER_OFFSET      0

void bn_shl(mpz_t bn, int bits);
void bn_shr(mpz_t bn, int bits);
void bn_init_mask(mpz_t mask, int bits);

template <typename T>
void bn_to_buffer(mpz_t bn, T *var, size_t words) {
    size_t countp;
    mpz_export(var, &countp, -1, BN_BUFFER_SIZE, 0, BN_BUFFER_OFFSET, bn);
    if(countp != words) {
        printf("WARNING: expected %ld words, got %ld\n", words, countp);
    }
}

template <typename T>
void bn_from_buffer(mpz_t bn, T *var, size_t words) {
    mpz_import(bn, words, -1, BN_BUFFER_SIZE, 0, BN_BUFFER_OFFSET, var);
}


class MSUDevice {
public:
    virtual ~MSUDevice() {}
    virtual void init(int msu_words_in, int msu_words_out) {}
    virtual void reset() {}
    virtual void compute_job(mpz_t msu_out, mpz_t msu_in) = 0;
};


class MSU {
public:
    gmp_randstate_t rand_state;

    int word_len;
    int bit_len;
    int redundant_elements;
    int nonredundant_elements;
    mpz_t modulus;

    int num_elements;
    int msu_words_in;
    int msu_words_out;
    
    mpz_t A;
    uint64_t t_start;
    uint64_t t_final;
    
    mpz_t msu_in;
    mpz_t msu_out;

    MSUDevice &device;
    
    MSU(MSUDevice &_d, int word_len,
        int redundant_elements, int nonredundant_elements, mpz_t _modulus);
    virtual ~MSU();

    int  run_fixed(uint64_t t_start, uint64_t t_final, mpz_t sq_in);
    int  run_random(uint64_t t_start, uint64_t t_final, bool rrandom);
    void prepare_random_job(bool rrandom);
    void compute_job();
    int  check_job();    
    void pack_to_msu(mpz_t msu_in, uint64_t t_start, uint64_t t_final, mpz_t A);
    void unpack_from_msu(mpz_t product, uint64_t *t_final, mpz_t msu_out);
    void compute_expected(mpz_t expected);
    void reduce_polynomial(mpz_t result, mpz_t poly, int padded_word_len);
};
#endif
