# VDF FPGA Competition Baseline Model

This repository contains the modular squaring multiplier baseline design for the upcoming VDF low latency multiplier competition (stay tuned for more details). The model is designed to be highly parameterized with support for a variety of bit widths. 

The algorithm used is a pipelined version of the multiplier developed by Erdinc Ozturk of Sabanci University and described in detail at MIT VDF Day 2019 (<https://dci.mit.edu/video-gallery/2019/5/29/survey-of-hardware-multiplier-techniques-new-innovations-in-low-latency-multipliers-e-ozturk>). 

There is also a very simple example using the high level operators (a*a)%N.

The model is not yet finalized. Expect to see changes leading up the competition start. Please reach out with any questions, comments, or feedback to hello@supranational.net.

# MSU

The MSU (Modular Squaring Unit) in `msu/rtl` is the top level component of the model. It is an SDAccel RTL Kernel compatible module responsible for interfacing to the outside world through AXI Lite. Internally it instantiates and controls execution of the modular squaring unit.

The model supports three build targets:

* Verilator simulation
* Hardware emulation
* FPGA execution

This document describes the steps required to execute the model on the supported targets.

# Recommended steps

## Step 1 - Enable simulation environment

Supported OS's are Ubuntu 18 and AWS F1 CentOS. The setup script requires sudo access to install dependencies.

```
# Install dependencies
./msu/scripts/simulation_setup.sh

# Run simulations
cd msu
make
```

## Step 2 - Develop your squarer in Python/RTL

Two squaring circuits are provided as examples, `modular_square/rtl/modular_square_simple.sv` and `modular_square/rtl/modular_square_8_cycles.sv`. You can start from either one. 

Search for "EDIT HERE" to quickly find starting points for editing:
```
find . -type f -exec grep "EDIT HERE" {} /dev/null \;
```

There are two testbench environments:
- Direct - the testbdench interacts directly with the squaring circuit.
- MSU - the testbench interacts with the MSU control module. 

The Direct testbench provides a simpler environment for developing. 

Note the default bitwidth for the simple squarer is 128bits due to verilator limitations. If you start with this design be sure to raise the bitwidth to 1024 in `msu/rtl/Makefile`.

You can run simulations for either of the designs:
```
cd msu 

# Simple squarer
make clean; DIRECT_TB=1 make simple

# 8 cycle Ozturk squarer
make clean; DIRECT_TB=1 make ozturk

# View waveforms
gtkwave rtl/obj_dir/logs/vlt_dump.vcd
```

## Step 3 - Synthesize

Once you have made changes to the multiplier you can run synthesis to in Vivado, AWS F1, or the test portal to measure and tune performance. 

**_Vivado_**

The Vivado GUI makes it easy to try different parameters and visualize results. 

```
# Simple squarer
cd msu/rtl/vivado_simple
./run_vivado.sh

# 8 cycle Ozturk squarer
cd msu/rtl/vivado_ozturk
./run_vivado.sh
```

This will launch Vivado with a project configured to build the Ozturk multiplier in out-of-context mode. While not identical to the sdaccel synthesis, it include a pblock that mimics the Shell Logic exclusion are so the results are pretty close. Another pblock forces the latency critical logic to stay in SLR2 for improved performance. 

**Bitwidth**: To test out smaller bitwidths edit the `run_vivado.sh` script. For the Ozturk multiplier be sure to run the script first at 1024 bits to generate the full complement of reduction lookup table files. **If you start with the simple squarer design be sure to increase the bitwidth once you add your multiplier to test at the full 1024 bits.**

**_AWS F1_**

You can use the AWS cloud to run synthesis for F1. See [aws_f1](docs/aws_f1.md).

**_On Premise_**

You can set up an on-premise environment to targeting the AWS F1 platform. See [on-premise](docs/onprem.md).

**_Test portal_**

TODO: You can submit models to be run on your behalf. 

## Step 4 - Hardening

Ultimately the `judge` target must pass to qualify for the competition. It runs simulations, hardware emulation, and synthesis, and bitstream generation. Like synthesis, you can run on-premise, use AWS F1, or use the test portal.

# Optimization Ideas

The following are some potential optimization paths.

* Try other algorithms such as Chinese Remainder Theorem, Montgomery/Barrett, etc. 
* Shorten the pipeline - we believe a 4-5 cycle pipeline is possible with this design
* Lengthen the pipeline - insert more pipe stages, run with a faster clock
* Change the partial product multiplier size. The DSPs are 26x17 bit multipliers and the modular squaring circuit supports using either by changing a define at the top.
* This design uses lookup tables stored in BlockRAM for the reduction step. These are easy to change to distributed memory and there is support in the model to use UltraRAM. 
* Optimize the compression trees and accumulators to make the best use of FPGA LUTs and CARRY8 primitives.
* Floorplan the design.
* Use High Level Synthesis (HLS) or other techniques.

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
