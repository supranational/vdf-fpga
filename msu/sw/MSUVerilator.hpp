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

#ifndef _MSU_VERILATOR_H_
#define _MSU_VERILATOR_H_

#include <verilated.h>
#include <MSU.hpp>
#include <Vtb.h>

// If "verilator --trace" is used, include the tracing class
#if VM_TRACE
# include <verilated_vcd_c.h>
#endif

extern vluint64_t *main_time_singleton;

class MSUVerilator : public MSUDevice {
public:
    Vtb *tb;
    VerilatedVcdC* tfp;

    // Current simulation time (64-bit unsigned)
    vluint64_t main_time = 0;

    // Watchdog cycle count
    uint64_t watchdog;

    mpz_t msu_in;
    mpz_t msu_out;
    int msu_words_in;
    int msu_words_out;
    
    MSUVerilator(int argc, char** argv);
    virtual ~MSUVerilator();
    
    virtual void init(MSU *_msu, Squarer *_squarer);
    virtual void reset();
    virtual void clock_cycle();
    virtual void compute_job(uint64_t t_start,
                             uint64_t t_final,
                             mpz_t sq_in,
                             mpz_t sq_out);

    void axi_write(mpz_t data, int words);
    void axi_read(mpz_t data, int words);

    void pet() {
        watchdog = 0;
    }
};

#endif
