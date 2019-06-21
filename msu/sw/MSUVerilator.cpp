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
    main_time_singleton = &main_time;
        
    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    Verilated::commandArgs(argc, argv);

    // Set debug level, 0 is off, 9 is highest presently used
    Verilated::debug(0);

    // Randomization reset policy
    Verilated::randReset(2);

    // Construct the Verilated model
    tb = new Vmsu_tb; 

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

void MSUVerilator::reset() {
    // Reset the device
    tb->reset = 1;
    tb->clk   = 1;
    tb->start = 0;
    clock_cycle();

    // Out of reset
    tb->reset = 0;
    clock_cycle();
    clock_cycle();
    clock_cycle();
}
    
void MSUVerilator::compute_job(mpz_t msu_out, mpz_t msu_in) {
    //gmp_printf("msu_in is 0x%Zx\n", msu_in);
    for(int i = 0; i < msu_words_in; i++) {
        tb->msu_in[i] = 0;
    }
    bn_to_buffer(msu_in, tb->msu_in, msu_words_in);
        
    // Load values
    tb->start     = 1;
    clock_cycle();
    tb->start     = 0;
        
    // Clock until result is valid
    int cycle_count = 0;
    while(!tb->valid && cycle_count < 1000) {
        clock_cycle();
        cycle_count++;
    }
        
    bn_from_buffer(msu_out, tb->msu_out, msu_words_out);
    gmp_printf("MSU result is 0x%Zx\n", msu_out);

    clock_cycle();
    clock_cycle();
    clock_cycle();
}
    

void MSUVerilator::clock_cycle() {
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

