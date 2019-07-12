# VDF FPGA Competition Baseline Model

This repository contains the modular squaring multiplier baseline design for the upcoming VDF low latency multiplier competition (stay tuned for more details). The model is designed to be highly parameterized with support for a variety of bit widths. 

The algorithm used is a pipelined version of the multiplier developed by Erdinc Ozturk of Sabanci University and described in detail at MIT VDF Day 2019 (<https://dci.mit.edu/video-gallery/2019/5/29/survey-of-hardware-multiplier-techniques-new-innovations-in-low-latency-multipliers-e-ozturk>). 

The model is not yet finalized. Expect to see changes leading up the competition start. Please reach out with any questions, comments, or feedback to hello@supranational.net.

**Table of Contents**

- [MSU](#msu)
- [Potential Optimizations](#potential-optimizations)
- [Verilator Simulation](#verilator-simulation)
  - [Dependencies (Ubuntu)](#dependencies-ubuntu)
  - [Dependencies (CentOS)](#dependencies-centos)
  - [Regressions](#regressions)
  - [Single simulation runs](#single-simulation-runs)
- [AWS F1](#aws-f1)
  - [Host instantiation](#host-instantiation)
  - [Host setup](#host-setup)
  - [Hardware Emulation](#hardware-emulation)
  - [Hardware Synthesis](#hardware-synthesis)
  - [FPGA Execution](#fpga-execution)
- [SDAccel On-Premise](#sdaccel-on-premise)
  - [Ubuntu 18](#ubuntu-18)
  - [Environment](#environment)
- [Vivado Out-of-context Synthesis](#vivado-out-of-context-synthesis)
- [References](#references)

# MSU

The MSU (Modular Squaring Unit) in `msu/rtl` is the top level component of the model. It is responsible for interfacing to the outside world through AXI Lite, instantiates the modular squaring unit, and controls execution.

The model supports three build targets:

* Verilator simulation
* Hardware emulation
* FPGA execution

This document describes the steps required to execute the model on the supported targets.

**Recommended steps to get started**

1. Clone this model, run verilator simulations. This should work on a laptop and no licenses are required. 
1. Develop your new and improved multiplier.
1. Run hardware emulation, either on-premise or using an AWS host. If you don't have the necessary licenses this can wait.
1. Use Vivado out-of-context synthesis mode to understand and tune your design.
1. Run hardware emulation and debug any problems.
1. Use the SDAccel synthesis flow to verify and fine tune the results.
1. Test the design on FPGA hardware for functionality and performance. 

# Potential Optimizations

The following are some potential optimization paths.

* Try other algorithms such as Chinese Remainder Theorem, Montgomery/Barrett, etc. 
* Shorten the pipeline - we believe a 4-5 cycle pipeline is possible with this design
* Lengthen the pipeline - insert more pipe stages, run with a faster clock
* Change the partial product multiplier size. The DSPs are 26x17 bit multipliers and the modular squaring circuit supports using either by changing a define at the top.
* This design uses lookup tables stored in BlockRAM for the reduction step. These are easy to change to distributed memory and there is support in the model to use UltraRAM. 
* Optimize the compression trees and accumulators to make the best use of FPGA LUTs and CARRY8 primitives.
* Floorplan the design.
* Use High Level Synthesis (HLS) or other techniques.

# Verilator Simulation

## Dependencies

GMP, Verilator, and python3 are required to build and run the model. 

Run the setup script to install the required dependencies on Ubuntu or CentOS:
```
./msu/scripts/simulation_setup.sh
```

Note that on Ubuntu this will build verilator from source and install it in /usr/local/bin since it is not available as a package. 

## Regressions

Regressions:
```
cd msu
make
```

## Single simulation runs

You can perform single simulation runs for development, debug, etc. from the rtl directory.

```
cd msu/rtl
make
```

Many aspects of the run can be configured by editing the Makefile or setting environment variables. It is often convenient to do this inline as such:
```
ITERATIONS=1 T_FINAL=10 make
```

# AWS F1

AWS F1 supports hardware emulation as well as FPGA accelerated execution. 

The typical workflow involves two types of hosts. You will most likely have to submit a request for an instance limit increase. This process is described in the error message if you try to instantiate one of these hosts and your limit is insufficient.
- Development, using a z1d.2xlarge with no attached FPGA
- Accelerated, using a f1.2xlarge with attached FPGA

AWS provides general information for using F1 (<https://github.com/aws/aws-fpga/blob/master/SDAccel/README.md>). 

A distilled down set of instructions specific to this design follows.

**Note that you can also enable AWS F1 hardware emulation and synthesis on-premise. See [SDAccel On-Premise](#sdaccel-on-premise)**

## Host instantiation

We assume some familiarity with the AWS environment. To instantiate a new AWS host for working with the FPGA follow these steps:

1. Login to the AWS page <https://aws.amazon.com/>, go to the EC2 service portal
1. Click on Launch Instance
1. For AMI, go to AWS Marketplace, then search for FPGA
1. Choose FPGA Developer AMI
1. For instance type choose z1d.2xlarge for development, f1.2xlarge for FPGA enabled, then Review and Launch
1. For configuration of the host we recommend:
  - Increase root disk space by about 20GB for an f1.2xlarge, 60GB for a z1d.2xlarge.
  - Add a descriptive tag to help track instances and volumes
1. Launch the instance
1. In the EC2 Instances page, select the instance and choose Actions->Connect. This will tell you the instance hostname that you can ssh to. 
  - Note that for the FPGA Developer AMI the username will be 'centos'
  - Log in with `ssh centos@HOST`

You may find it convenient to install additional ssh keys for github, etc. 

## Host setup

Some initial setup is required for new F1 hosts. See <https://github.com/aws/aws-fpga/blob/master/SDAccel/README.md> for more detail.

We've encapsulated a typical setup that includes vnc:
```
./msu/scripts/f1_setup.sh
```

You can then optionally start a vncserver if you prefer to work in an X-windows environment:
```
# Start a vncserver
vncserver
```

Connect using ssh to tunnel the vnc port:
```
ssh -L 5908:localhost:5901 centos@HOST
```

And view it locally:
```
vncviewer :8
```

Once you have vnc up run vncconfig to enable copy/paste:
```
vncconfig &
```

## Hardware Emulation

To build and run a test in hardware emulation:
```
source ./msu/scripts/sdaccel_env.sh
cd msu
make clean
make hw_emu
```

Rerunning without cleaning the build will retain the hardware emulation (hardware) portion while rebuilding and executing the host (software) portion.

Tracing is enabled by default in the hw_emu run. To view the resulting waveforms run:
```
vivado -source open_waves.tcl
```

## Hardware Synthesis 

Synthesis and Place&Route compile the design from RTL into a bitstream that can be loaded on the FPGA. This step takes 1-3 hours depending on complexity of the design, host speed, synthesis targets, etc. 

You can enable a **faster run** by relaxing the kernel frequency (search for kernel_frequency in the Makefile) or building a smaller multiplier (comment out 1024b, uncomment 128b in the Makefile). This is often convenient when trying things out.

```
source ./msu/scripts/sdaccel_env.sh
cd msu/rtl/sdaccel
make clean
make hw
```

Once synthesis successfully completes you can register the new image. Follow the instructions in <https://github.com/aws/aws-fpga/blob/master/SDAccel/docs/Setup_AWS_CLI_and_S3_Bucket.md> to setup an S3 bucket. This only needs to be done once. We assume a bucket name 'vdf'. Once that is done run the following:

```
# Configure AWS credentials. You should only need to do this once on a given
# host
#    AWS Access Key ID [None]: XXXXXX
#    AWS Secret Access Key [None]: XXXXXX
#    Default region name [None]: us-east-1
#    Default output format [None]: json
aws configure

# Register the new bitstream
cd obj/xclbin
KERNEL=vdf
BUCKET=vdf
$SDACCEL_DIR/tools/create_sdaccel_afi.sh -xclbin=$KERNEL.hw.xilinx_aws-vu9p-f1-04261818_dynamic_5_0.xclbin -o=$KERNEL.hw.xilinx_aws-vu9p-f1-04261818_dynamic_5_0 -s3_bucket=$BUCKET -s3_dcp_key=dcp -s3_logs_key=logs
cat *afi_id.txt

# Check status using the afi_id from the last step. It should say 
# pending for about 30 minutes, then available.
aws ec2 describe-fpga-images --fpga-image-ids afi-XXXXXXXXXXXX

# Copy the required files to an FPGA enabled host for execution:
HOST=xxxx # Your F1 hostname here
scp ../host vdf.hw.xilinx_aws-vu9p-f1-04261818_dynamic_5_0.awsxclbin centos@$HOST:.
```

## FPGA Execution

Once you have synthesized a bitstream, registered it using `create_sdaccel_afi.sh`, describe-fpga-image reports available, and copied the necessary files to an f1 machine you are ready to execute on the FPGA.

Currently debug mode is required due to a known AWS issue. Create an `sdaccel.ini` file in the same directory you will be running from: 
```
cat <<EOF > sdaccel.ini 
[Debug]
profile=true
EOF
```

Execute the host driver code. This will automatically load the image referenced by the awsxclbin file onto the FPGA. 
```
sudo su
source $AWS_FPGA_REPO_DIR/sdaccel_runtime_setup.sh 

# Run a short test and verify the result in software
./host -e -u 0 -f 100

# Run a billion iterations starting with an input of 2
./host -u 0 -s 0x2 -f 1000000000
```

The expected result of 2^2^1B using the default 1k (64 coefficient) modulus in the Makefile is:
`305939394796769797811431929207587607176284037479412924905827147439718856946037842431593490055940763973150879770720223457997191020439404083394702653096083649807090448385799021330059496823106654989629199132438283594347957634468046231084628857389350823217443926925454895121571284954146032303555585511855910526`


# SDAccel On-Premise

It's possible to perform hardware emulation and synthesis on-premise using the flow defined by AWS. 

The steps to enable an on-premise are described here: <https://github.com/aws/aws-fpga/blob/master/SDAccel/docs/On_Premises_Development_Steps.md>.

You will need a license for the vu9p in Vivado and for SDAccel. Xilinx offers trial licenses on their website. The licenses should be loaded through the license manager, which is accessed from the Vivado Help menu. 

Host requirements: 32GB of memory is preferred though 16GB of memory should be sufficient. Single threaded performance is the main determinant of runtime. 

## Ubuntu 18

While Ubuntu 18 is not officially supported, the on-premise flow can be made to work with a few additional changes after installing SDAccel.

```
# Link to the OS installed version of libstdc++:
cd /tools/Xilinx/SDx/2018.3/lib/lnx64.o/Default/
mv libstdc++.so.6 libstdc++.so.6_orig
ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6

cd /tools/Xilinx/SDx/2018.3/lib/lnx64.o/Default/
mv libstdc++.so.6 libstdc++.so.6_orig
ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6

# After the changes above this should report "ERROR: no card found"
/opt/xilinx/xrt/bin/xbutil validate

# Some of the python scripts reference /bin/env
cd /bin
sudo ln -s /usr/bin/env
```

## helloworld

The `helloworld_ocl` example should now successfully complete:
```
source ./msu/scripts/sdaccel_env.sh
cd $AWS_FPGA_REPO_DIR/SDAccel/examples/xilinx/getting_started/host/helloworld_ocl

# in Makefile, change DEVICE to:
DEVICE := $(AWS_PLATFORM)

make cleanall; make TARGETS=sw_emu DEVICES=$AWS_PLATFORM check
```

You can now follow the hardware emulation and synthesis flows described above. 

To register the image built from on-premise synthesis first copy the msu/rtl/obj/xclbin/vdf.hw.xilinx_aws-vu9p-f1-04261818_dynamic_5_0.xclbin and host files to an AWS F1 instance, then run `create_sdaccel_afi.sh`.

# Vivado Out-of-context Synthesis

TODO


# References

Information on VDFs: <https://vdfresearch.org/>

Xilinx offers a wide array of instructional videos online, including:
  * EC2 F1 Lab: <https://www.youtube.com/watch?v=RvTSyVa6bCw>
  * Synthesis: <https://www.youtube.com/watch?v=lFc3JoiOOa8>
  * Floorplanning: <https://www.youtube.com/watch?v=W8D2WghRR4Y>
  * SDAccel kernel debug: <https://www.youtube.com/watch?v=pmogNAEdkcE>

AWS online documentation:
  * SDAccel Quick Start: <https://github.com/aws/aws-fpga/blob/master/SDAccel/README.md>
  * SDAccel Docs: <https://github.com/aws/aws-fpga/tree/master/SDAccel/docs>
  * Shell Interface: <https://github.com/aws/aws-fpga/blob/master/hdk/docs/AWS_Shell_Interface_Specification.md>
  * Simulating CL Designs: <https://github.com/aws/aws-fpga/blob/master/hdk/docs/RTL_Simulating_CL_Designs.md>
