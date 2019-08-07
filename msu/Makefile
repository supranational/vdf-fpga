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


# Main targets

all: hw_emu

# Requires verilator
regress: sim hw_emu_simple judge

judge: synthesis

hw_emu_simple:
	make clean
	OBJ=obj_hw_emu MOD_LEN=1024 SIMPLE_SQ=1 $(MAKE) -C $(SDACCEL_DIR) hw_emu

hw:
	MOD_LEN=1024 SIMPLE_SQ=0 $(MAKE) -C $(SDACCEL_DIR) hw


# This target is used by the test portal to perform hardware emulation
hw_emu:
	make clean

	@echo ""
	@echo "############################################################"
	@echo "# Running hardware emulation..."
	@echo "############################################################"
	OBJ=obj_hw_emu MOD_LEN=1024 SIMPLE_SQ=0 \
		$(MAKE) -C $(SDACCEL_DIR) hw_emu |& tee hw_emu.log

# This target is used by the test portal to perform synthesis
synthesis:
	make clean

	@echo ""
	@echo "############################################################"
	@echo "# Running hardware emulation..."
	@echo "############################################################"
	OBJ=obj_hw_emu MOD_LEN=1024 SIMPLE_SQ=0 \
		$(MAKE) -C $(SDACCEL_DIR) hw_emu |& tee hw_emu.log

	@echo ""
	@echo "############################################################"
	@echo "# Synthesizing..."
	@echo "############################################################"
	OBJ=obj_hw     MOD_LEN=1024 SIMPLE_SQ=0 \
		$(MAKE) -C $(SDACCEL_DIR) hw     |& tee hw.log


# Additional, mostly verilator, targets

sim: simple simple ozturk ozturk

ozturk:
	$(MAKE) clean
	$(MAKE) -C rtl run

simple:
	$(MAKE) clean
	SIMPLE_SQ=1 $(MAKE) -C rtl run


hw_emu_random:
	make clean
	$(MAKE) -C $(SDACCEL_DIR) hw_emu_random


clean:
	$(MAKE) -C rtl clean
	$(MAKE) -C $(SDACCEL_DIR) clean


# These work but seems unnecessary to maintain another testbench variant
# ozturk:
# 	$(MAKE) clean
# 	DIRECT_TB=1 $(MAKE) -C rtl run

# simple:
# 	$(MAKE) clean
# 	SIMPLE_SQ=1 DIRECT_TB=1 $(MAKE) -C rtl run
