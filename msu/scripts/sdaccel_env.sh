#!/bin/bash

# source this script to setup the environment F1 development

hostname|grep ec2 > /dev/null
if [ $? == 0 ]
then
    echo "Setting up the an EC2 environment..."

else
    echo "Setting up an on-premise environment..."
    
    export XILINX_SDX=/tools/Xilinx/SDx/2018.3
    PATH=$PATH:$XILINX_SDX/bin
    export AWS_FPGA_REPO_DIR=~/src/project_data/aws-fpga
fi

git clone https://github.com/aws/aws-fpga.git $AWS_FPGA_REPO_DIR
pushd $AWS_FPGA_REPO_DIR

# The following will require sudo
source sdaccel_setup.sh

popd
