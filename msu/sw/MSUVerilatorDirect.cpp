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

#include <MSUVerilator.hpp>

vluint64_t *main_time_singleton = 0;

// Called by $time in Verilog
double sc_time_stamp() {
    if(main_time_singleton) {
        return *main_time_singleton;
    } else {
        return(0);
    }
}

MSUVerilator::MSUVerilator(int argc, char** argv) {
    mpz_inits(msu_in, msu_out, 0);

    main_time_singleton = &main_time;

    pet();
        
    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    Verilated::commandArgs(argc, argv);

    // Set debug level, 0 is off, 9 is highest presently used
    Verilated::debug(0);

    // Randomization reset policy
    Verilated::randReset(2);

    // Construct the Verilated model
    tb = new Vtb; 

    // If verilator was invoked with --trace argument,
    // and if at run time passed the +trace argument, turn on tracing
    tfp = NULL;
#if VM_TRACE
    const char* flag = Verilated::commandArgsPlusMatch("trace");
    if (flag && 0==strcmp(flag, "+trace")) {
        Verilated::traceEverOn(true);
        VL_PRINTF("Enabling waves into obj_dir/logs/vlt_dump.vcd...\n");
        tfp = new VerilatedVcdC;
        tb->trace(tfp, 99);  // Trace 99 levels of hierarchy
        // Not supported in default Centos version
        //Verilated::mkdir("logs");
        tfp->open("logs/vlt_dump.vcd");  // Open the dump file
    }
#endif
}
    
MSUVerilator::~MSUVerilator() {
    mpz_clears(msu_in, msu_out, 0);
    
    tb->final();

    // Close trace if opened
#if VM_TRACE
    if (tfp) { tfp->close(); tfp = NULL; }
#endif

    //  Coverage analysis (since test passed)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif

    // Destroy model
    delete tb; tb = NULL;
}

void MSUVerilator::init(MSU *_msu, Squarer *_squarer) {
    MSUDevice::init(_msu, _squarer);

    int nonredundant_elements = msu->mod_len / WORD_LEN;
    int num_elements = nonredundant_elements + REDUNDANT_ELEMENTS;
    msu_words_in  = (T_LEN/MSU_WORD_LEN*2 + (nonredundant_elements+1)/2);
    msu_words_out = (T_LEN/MSU_WORD_LEN + num_elements);
}

void MSUVerilator::reset() {
    // Reset the device
    tb->reset           = 1;
    tb->clk             = 1;
    tb->start           = 0;

    for(int i = 0; i < 10; i++) {
        clock_cycle();
    }

    // Out of reset
    tb->reset           = 0;
    clock_cycle();
    clock_cycle();
    clock_cycle();
}

void MSUVerilator::compute_job(uint64_t t_start,
                               uint64_t t_final,
                               mpz_t sq_in,
                               mpz_t sq_out) {
    reset();
    
    // Number of 32-bit words we need to copy from mpz to sq_in/sq_out
    //int sq_words = msu->mod_len / 8 / BN_BUFFER_SIZE;
    bn_to_buffer(sq_in, tb->sq_in, squarer->msu_words_in(), true, true);

    // Load values
    tb->start     = 1;
    clock_cycle();
    tb->start     = 0;

    uint64_t t_cur = t_start;
    while(t_cur < t_final ){
        while(!tb->valid) {
            clock_cycle();
        }
        pet();

        t_cur++;
        if(t_cur == t_final) {
            break;
        }

        clock_cycle();
    }
        
    bn_from_buffer(msu_out, tb->sq_out, squarer->msu_words_out());
    gmp_printf("squarer result is 0x%Zx\n", msu_out);

    squarer->unpack(sq_out, 0, msu_out, WORD_LEN);

    clock_cycle();
    clock_cycle();
    clock_cycle();
}

void MSUVerilator::clock_cycle() {
    watchdog++;
    if(watchdog == 1000) {
        printf("ERROR: Hit cycle count limit\n");
#if VM_TRACE
        if (tfp) { tfp->close(); tfp = NULL; }
#endif
        exit(0);
    }
    
    main_time++;
    tb->clk = 0;
    tb->eval();
#if VM_TRACE
    if (tfp) tfp->dump (main_time);
#endif
        
    main_time++;
    tb->clk = 1;
    tb->eval();
#if VM_TRACE
    if (tfp) tfp->dump (main_time);
#endif
}

