# Verilator

The Ozturk design supports verilator as a simulator. 

While we're big fans of verilator, it unfortunately doesn't support 1024 bit modular squaring using * and %. As a result the default bitwidth for this design when using verilator is 128 bits. We found it can also be finicky with large bitwidths. Unpacked arrays of smaller words seems more stable.

Enabling verilator takes just a few steps on Ubuntu 18 and AWS F1 CentOS. The setup script requires sudo access to install dependencies.

```
# Install dependencies
./msu/scripts/simulation_setup.sh

# Run simulations for both designs
cd msu
make
```

The verilator testbench instantiates the MSU portion of the design as well as the squarer circuit. The MSU interfaces to the SDAccel interfaces and provides control to count the number iterations, capture the result, and send it back to the host driver. 

Simulating the MSU design is a fast way to iterate, debug, and test before moving on to hardware emulation. 

You can run simulations and view waveforms for a particular design as follows:
```
cd msu 

# Simple squarer
make clean; make simple

# 8 cycle Ozturk squarer
make clean; make ozturk

# View waveforms
gtkwave rtl/obj_dir/logs/vlt_dump.vcd
```
