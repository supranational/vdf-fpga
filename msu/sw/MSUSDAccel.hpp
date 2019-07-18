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

#ifndef _MSU_SDACCEL_H_
#define _MSU_SDACCEL_H_

#include <MSU.hpp>
#include <xcl2.hpp>
#include <vector>

#define KERNEL_NAME "vdf"

class OpenCLContext {
public:
    bool quiet;

    // Host memory for buffers
    std::vector<uint32_t,aligned_allocator<uint32_t>> input_buf;
    std::vector<uint32_t,aligned_allocator<uint32_t>> output_buf;
    int msu_words_in;
    int msu_words_out;

    // OpenCL structures
    cl::Context *context;
    cl::CommandQueue *q;
    cl::Program *program;
    cl::Kernel *krnl_vdf;
    cl::Buffer *inBuffer;
    cl::Buffer *outBuffer;
    std::vector<cl::Memory> inBufferVec;
    std::vector<cl::Memory> outBufferVec;

    OpenCLContext() {}
    ~OpenCLContext();
    void init(int msu_words_in, int msu_words_out);
    void compute_job(mpz_t msu_out, mpz_t msu_in);
};

class MSUSDAccel : public MSUDevice {
    OpenCLContext ocl;
public:
    mpz_t msu_in;
    mpz_t msu_out;
    int msu_words_in;
    int msu_words_out;

    MSUSDAccel() {
        mpz_inits(msu_in, msu_out, 0);
    }
    virtual ~MSUSDAccel() {
        mpz_clears(msu_in, msu_out, 0);
    }
    
    virtual void init(MSU *_msu, Squarer *_squarer);
    virtual void compute_job(uint64_t t_start,
                             uint64_t t_final,
                             mpz_t sq_in,
                             mpz_t sq_out);

    virtual void set_quiet(bool _quiet) {
        quiet     = _quiet;
        ocl.quiet = _quiet;
    }
};

#endif
