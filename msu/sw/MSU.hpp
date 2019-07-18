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
#include <Config.h>
#include <Squarer.hpp>


template <typename T>
void bn_to_buffer(mpz_t bn, T *var, size_t words,
                  bool suppress_warning = false,
                  bool zero_extra_words = false) {
    size_t countp;
    mpz_export(var, &countp, -1, BN_BUFFER_SIZE, 0, BN_BUFFER_OFFSET, bn);
    if(countp != words) {
        if(!suppress_warning) {
            printf("WARNING: expected %ld words, got %ld\n", words, countp);
        }
        if(zero_extra_words) {
            for(unsigned i = countp; i < words; i++) {
                var[i] = 0;
            }
        }
    }
}

template <typename T>
void bn_from_buffer(mpz_t bn, T *var, size_t words) {
    mpz_import(bn, words, -1, BN_BUFFER_SIZE, 0, BN_BUFFER_OFFSET, var);
}

class MSU;

class MSUDevice {
protected:
    bool quiet;
    MSU *msu;
    Squarer *squarer;
public:
    virtual ~MSUDevice() {}
    virtual void init(MSU *_msu, Squarer *_squarer) {
        msu = _msu;
        squarer = _squarer;
    }
    virtual void reset() {}
    virtual void clock_cycle() {}
    virtual void compute_job(uint64_t t_start,
                             uint64_t t_final,
                             mpz_t sq_in,
                             mpz_t sq_out) = 0;
    virtual void set_quiet(bool _quiet) {
        quiet = _quiet;
    }
};

class MSU {
public:
    gmp_randstate_t rand_state;

    int mod_len;
    mpz_t modulus;

    int num_elements;
    
    mpz_t sq_in;
    mpz_t sq_out;
    uint64_t t_start;
    uint64_t t_final;
    
    uint64_t compute_time;

    bool quiet;

    MSUDevice &device;
    
    MSU(MSUDevice &_d, int mod_len, mpz_t _modulus);
    virtual ~MSU();

    int  run_fixed(uint64_t t_start, uint64_t t_final, mpz_t sq_in, 
                   bool check);
    int  run_random(uint64_t t_start, uint64_t t_final, bool rrandom, 
                    bool check);
    void prepare_random_job(bool rrandom);
    void compute_job();
    int  check_job();    

    void set_quiet(bool _quiet) {
        quiet = _quiet;
    }
};
#endif
