#!/bin/bash

grep Ubuntu /etc/os-release > /dev/null
if [ $? == 0 ]
then
    # Ubuntu
    echo "Running Ubuntu setup..."
    
    sudo apt update -y
    sudo apt install -y python3 libgmp-dev gtkwave

    wget https://www.veripool.org/ftp/verilator-4.016.tgz
    sudo apt-get install -y make autoconf g++ flex bison
    tar xvzf verilator*.t*gz
    cd verilator-4.016/
    ./configure 
    make -j 4
    sudo make install

else
    # Assume CentOS
    echo "Running CentOS setup..."
    sudo yum update -y
    sudo yum install -y gmp-devel verilator python36 gtkwave
fi

export PATH=/tools/Xilinx/Vivado/2018.3/bin:$PATH
