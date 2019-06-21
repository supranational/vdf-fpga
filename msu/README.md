# MSU

The MSU (Modular Squaring Unit) is the top level component of the model. It is responsible for interfacing to the outside world through AXI Lite and controlling execution of the modular squaring unit. 

The model supports three build targets:
- simulation, using verilator
- hardware emulation
- FPGA

This document describes the steps required to execute the model on the supported targets.

## Dependencies

### Ubuntu

GMP, Verilator, and python3 are required to build and run the model. 

**Python3**

```
sudo apt install python3
```

**GMP**

https://gmplib.org/

You can install from source or apt. 

Apt:
```
sudo apt install libgmp-dev
```

Source:
```
wget https://gmplib.org/download/gmp/gmp-6.1.2.tar.lz

# If lzip is not installed.  Alternatively there are other gmp compressed files
sudo apt install lzip

tar --lzip -xvf gmp-6.1.2.tar.lz 
cd gmp-6.1.2/
./configure 
make
sudo make install
```

**Verilator**

https://www.veripool.org/projects/verilator/wiki/Installing

```
sudo apt update
wget https://www.veripool.org/ftp/verilator-4.016.tgz
sudo apt-get install make autoconf g++ flex bison
tar xvzf verilator*.t*gz
cd verilator-4.016/
./configure 
make -j 4
sudo make install
```
### CentOS

The following dependencies are required to run on the AWS FPGA development servers:

```
sudo yum update -y
sudo yum install -y gmp-devel verilator python36
```

## Simulation

Regressions:
```
cd msu
make
```

## Hardware Emulation

Hardware emulation requires a Vivado and SDAccel license and install. The easiest way to try it out is to use AWS F1. General instructions are provided by AWS for setup. This model uses the RTL Kernel approach. 

https://github.com/aws/aws-fpga/blob/master/SDAccel/README.md

Follow the instructions for "Github and Environment Setup". When instantiating an instance it helps to increase the default drive space for the non-root drive from 5GB to, for example, 30GB. To gain access to the additional space you'll have to resize the volume once the instance is up: 
```
sudo resize2fs /dev/nvme1n1
```

Install the 2018.3 SDAccel example repo:
```
git clone https://github.com/aws/aws-fpga.git $AWS_FPGA_REPO_DIR
cd /home/centos/src/project_data/aws-fpga/SDAccel/examples
rmdir xilinx_2018.3
git clone https://github.com/Xilinx/SDAccel_Examples.git xilinx_2018.3
cd xilinx_2018.3
git checkout b2884db
```

To build and run in hardware emulation:
```
source $AWS_FPGA_REPO_DIR/sdk_setup.sh
source $AWS_FPGA_REPO_DIR/sdaccel_setup.sh
cd msu
make hw_emu
```

## FPGA

We're still refining the intructions for this - stay tuned!
