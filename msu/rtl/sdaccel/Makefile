#
#  Copyright 2019 Supranational, LLC
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

OBJ ?= obj

# Build the simulation model plus the host. To rebuild the RTL
# after making changes you must 'make clean' first.
hw_emu_random:
	mkdir -p $(OBJ)
	RANDOM_MODULUS=1 \
            $(MAKE) -C $(OBJ) -f ../Makefile.sdaccel TARGETS=hw_emu check

hw_emu:
	mkdir -p $(OBJ)
	time $(MAKE) -C $(OBJ) -f ../Makefile.sdaccel TARGETS=hw_emu check

# Build the host software
host: 
	$(MAKE) -C $(OBJ) -f ../Makefile.sdaccel TARGETS=hw host

# Build an FPGA model
hw:
	mkdir -p $(OBJ)
	time $(MAKE) -C $(OBJ) -f ../Makefile.sdaccel TARGETS=hw all

# Gather files to copy to F1 machine
to_f1:
	$(MAKE) -C $(OBJ) -f ../Makefile.sdaccel to_f1

# Gather the sources needed for sdx for interactive hw emulation debug
sdx:
	mkdir -p $(OBJ)
	$(MAKE) -C $(OBJ) -f ../Makefile.sdaccel sdx

clean:
ifdef XILINX_SDX
	mkdir -p $(OBJ)
	$(MAKE) -C $(OBJ) -f ../Makefile.sdaccel cleanall
endif
	rm -fr $(OBJ)
	rm -fr $(OBJ)_hw_emu
	rm -fr $(OBJ)_hw

