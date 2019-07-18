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

SDACCEL_DIR=rtl/sdaccel

all: sim

regress: sim hw_emu_random

#
# EDIT HERE
# Edit the rules below to run appropriate simulations, hw emulation, and
# synthesis for your model depending on where you start:
#   modular_square_simple  - Remove SIMPLE_SQ builds
#   modular_square_8_cycle - Remove non SIMPLE_SQ builds
#   other                  - Edit rtl/Makefile and rtl/sdaccel/Makefile to
#                            include your code.
#
# DIRECT_TB mode bypasses the msu (the SDAccel RTL Kernel adapter) and connects
# directly to the squaring circuit. This is the simplest flow for general
# development and testing. Ultimately you will need to test the msu flow as
# well so that it works in hardware emulation, synthesis, and the FPGA
# hardware.
#
# For initial multiplier development consider using the target "ozturk" or
# "simple".
#

sim: simple simple_msu ozturk ozturk_msu

ozturk_msu:
	$(MAKE) clean
	$(MAKE) -C rtl run

ozturk:
	$(MAKE) clean
	DIRECT_TB=1 $(MAKE) -C rtl run

simple_msu:
	$(MAKE) clean
	SIMPLE_SQ=1 $(MAKE) -C rtl run

simple:
	$(MAKE) clean
	SIMPLE_SQ=1 DIRECT_TB=1 $(MAKE) -C rtl run

judge:
	$(MAKE) clean

	@echo "Running functional tests..."
	$(MAKE) -C rtl judge

	@echo "Running hardware emulation..."
	$(MAKE) hw_emu_random

	@echo "Synthesizing..."
	$(MAKE) hw

hw_emu:
	make clean
	$(MAKE) -C $(SDACCEL_DIR) hw_emu
	make clean
	SIMPLE_SQ=1 $(MAKE) -C $(SDACCEL_DIR) hw_emu

hw_emu_random:
	make clean
	$(MAKE) -C $(SDACCEL_DIR) hw_emu_random

hw:
	$(MAKE) -C $(SDACCEL_DIR) hw

clean:
	$(MAKE) -C rtl clean
	$(MAKE) -C $(SDACCEL_DIR) clean

