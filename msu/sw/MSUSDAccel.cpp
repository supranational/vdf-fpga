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

#include <gmp.h>
#include <unistd.h>
#include <stdio.h>
#include <MSUSDAccel.hpp>

using namespace std;

// Print a buffer in 32 bit words. 
void print_buffer(const char *name, uint32_t *buffer, int size) {
    printf("BUFFER: %s size %d words, %d bytes\n", name, size, size * 4);
    for(int i = 0; i < size; i++) {
        printf("   %3d: 0x%04x\n", i, buffer[i]);
    }
}

// Print a buffer in 32 bit words as one long line.
void print_buffer_concise(const char *name, uint32_t *buffer, int size) {
    printf("%s: ", name);
    for(int i = 0; i < size; i++) {
        if(i != 0) {
            printf(", ");
        }
        printf("%05x", buffer[size - i - 1]);
    }
    printf("\n");
}

void OpenCLContext::init(int _msu_words_in, int _msu_words_out) {
    cl_int err;

    msu_words_in = _msu_words_in;
    msu_words_out = _msu_words_out;

    input_buf.resize(msu_words_in);
    output_buf.resize(msu_words_out);

    // Clear the data buffers
    int i = 0;
    for(i = 0; i < msu_words_in; i++) {
        input_buf[i] = 0;
    }
    for(i = 0; i < msu_words_out; i++) {
        output_buf[i] = 0;
    }

    // Create Program and Kernel
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[0];

    OCL_CHECK(err, context =
              new cl::Context(device, NULL, NULL, NULL, &err))
    OCL_CHECK(err, q =
              new cl::CommandQueue(*context, device,
                                   CL_QUEUE_PROFILING_ENABLE, &err));
    std::string device_name = device.getInfo<CL_DEVICE_NAME>(); 

    std::string binaryFile = xcl::find_binary_file(device_name, KERNEL_NAME);
    cl::Program::Binaries bins = xcl::import_binary_file(binaryFile);
    devices.resize(1);
    OCL_CHECK(err, program =
              new cl::Program(*context, devices, bins, NULL, &err));
    OCL_CHECK(err, krnl_vdf =
              new cl::Kernel(*program, KERNEL_NAME, &err));

    // Allocate OpenCL buffers in memory
    OCL_CHECK(err, inBuffer =
              new cl::Buffer(*context,
                             CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, 
                             (size_t)msu_words_in*MSU_BYTES_PER_WORD, 
                             input_buf.data(), &err));
    OCL_CHECK(err, outBuffer =
              new cl::Buffer(*context,
                             CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY, 
                             (size_t)msu_words_out*MSU_BYTES_PER_WORD, 
                             output_buf.data(), &err));
    inBufferVec.push_back(*inBuffer);
    outBufferVec.push_back(*outBuffer);
    
    // Set kernel arguments.
    // Not used
    OCL_CHECK(err, err = krnl_vdf->setArg(0, 0));
    OCL_CHECK(err, err = krnl_vdf->setArg(1, *inBuffer));
    OCL_CHECK(err, err = krnl_vdf->setArg(2, *outBuffer));
    // Not used
    OCL_CHECK(err, err = krnl_vdf->setArg(3, *outBuffer));
}

OpenCLContext::~OpenCLContext() {
    delete outBuffer;
    delete inBuffer;
    delete krnl_vdf;
    delete program;
}

void OpenCLContext::compute_job(mpz_t msu_out, mpz_t msu_in) {
    if(!quiet) {
        gmp_printf("msu_in is 0x%Zx\n", msu_in);
    }
    bn_to_buffer(msu_in, input_buf.data(), msu_words_in, true, true);
    //print_buffer_concise("msu_in", input_buf.data(), msu_words_in);
    
    cl_int err;
    
    // DMA the buffers to the FPGA
    OCL_CHECK(err, err = q->enqueueMigrateMemObjects(inBufferVec, 0));

    // Launch the Kernel
    OCL_CHECK(err, err = q->enqueueTask(*krnl_vdf));

    // DMA the results from FPGA to host
    OCL_CHECK(err, err =
              q->enqueueMigrateMemObjects(outBufferVec,
                                          CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q->finish());

    // Extract the result
    bn_from_buffer(msu_out, output_buf.data(), msu_words_out);
    if(!quiet) {
        gmp_printf("msu_out is 0x%Zx\n", msu_out);
        //print_buffer_concise("msu_out", output_buf.data(), msu_words_out);
    }
}

void MSUSDAccel::init(MSU *_msu, Squarer *_squarer) {
    MSUDevice::init(_msu, _squarer);

    int nonredundant_elements = msu->mod_len / WORD_LEN;
    int num_elements = nonredundant_elements + REDUNDANT_ELEMENTS;
    msu_words_in  = (T_LEN/MSU_WORD_LEN*2 + (nonredundant_elements+1)/2);
    msu_words_out = (T_LEN/MSU_WORD_LEN + num_elements);
    
    ocl.init(msu_words_in, msu_words_out);
}

void MSUSDAccel::compute_job(uint64_t t_start,
                               uint64_t t_final,
                               mpz_t sq_in,
                               mpz_t sq_out) {
    squarer->pack(msu_in, t_start, t_final, sq_in);
    ocl.compute_job(msu_out, msu_in);

    uint64_t t_final_out;
    squarer->unpack(sq_out, &t_final_out, msu_out, WORD_LEN);
}
