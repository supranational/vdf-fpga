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

default: run 

# Multiplier configuration
include multiplier.mk

# Test configuration
ITERATIONS            ?= 25
T_FINAL               ?= 3
FASTSIM               ?= 1
INTERMEDIATES         ?= 0

include ./verilator.mk


# Overrides to reproduce specific cases
# ITERATIONS = 1
# T_FINAL = 30
# MOD_LEN = 128
# MODULUS = 302934307671667531413257853548643485645
# SQ_IN = 0x45558c7335696741d41c91186caf806b

ifdef SQ_IN
SQ_IN_FLAG             = -s $(SQ_IN)
endif
ifeq ($(RRANDOM), 1)
RRANDOM_FLAG           = -1
endif
ifeq ($(FASTSIM), 1)
VERILATOR_FLAGS       += -DFASTSIM=1
endif

ifeq ($(DIRECT_TB), 1)
  ifeq ($(SIMPLE_SQ), 1)
  TOP_FILE             = modular_square_simple.sv
  else
  TOP_FILE             = modular_square_wrapper.sv
  endif
else
TOP_FILE               = msu.sv
endif

VERILATOR_FLAGS       += -DMOD_LEN_DEF=$(MOD_LEN)
VERILATOR_FLAGS       += -DMODULUS_DEF=$(MOD_LEN)\'d$(MODULUS)
VERILATOR_FLAGS       += -CFLAGS '-I../../sw -Wall -std=c++11'
VERILATOR_FLAGS       += ../sw/MSU.cpp
VERILATOR_FLAGS       += --prefix Vtb

ifeq ($(SIMPLE_SQ), 1)
VERILATOR_FLAGS       += -DSIMPLE_SQ=1
VERILATOR_FLAGS       += -CFLAGS '-DSIMPLE_SQ=1'
endif
ifeq ($(DIRECT_TB), 1)
VERILATOR_FLAGS       += -CFLAGS '-DDIRECT_TB=1'
VERILATOR_FLAGS       += ../sw/MSUVerilatorDirect.cpp
else
VERILATOR_FLAGS       += ../sw/MSUVerilator.cpp
endif

VERILATOR_FLAGS       += -DMSU_SQ_IN_BITS_DEF=$(SQ_IN_BITS)
VERILATOR_FLAGS       += -DMSU_SQ_OUT_BITS_DEF=$(SQ_OUT_BITS)

MODSQR_PATH            = $(realpath ../../modular_square/rtl)

######################################################################

run: msuconfig.vh
	@echo
	@echo "-- Large Integer Modular Squaring"

ifeq ($(SIMPLE_SQ), 0)
	@echo
	@echo "-- GENERATE LUTs -----------------"
	mkdir -p obj_dir
	cd obj_dir && $(MODSQR_PATH)/gen_reduction_lut.py \
                          --nonredundant $(NONREDUNDANT_ELEMENTS) \
                          --modulus $(MODULUS)
endif

	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) $(VERILATOR_FLAGS) -f input.vc $(TOP_FILE) ../sw/main.cpp

	@echo
	@echo "-- COMPILE -----------------"
	LIBS=-lgmp $(MAKE) -j 4 -C obj_dir -f Vtb.mk

	@echo
	@echo "-- RUN ---------------------"
	@mkdir -p obj_dir/logs
	cd obj_dir && ./Vtb $(TRACE_FLAG) -i $(ITERATIONS) \
                          -n $(MOD_LEN) \
                          -t $(INTERMEDIATES) \
                          -f $(T_FINAL) \
                          -m $(MODULUS) $(RRANDOM_FLAG) $(SQ_IN_FLAG) \
                          -e

	@echo
	@echo "-- DONE --------------------"
ifeq ($(VERILATOR_TRACE), 1)
	@echo "To see waveforms:"
	@echo "gtkwave obj_dir/logs/vlt_dump.vcd &"
endif
	@echo

# Run multiple tests with a random modulus
judge:
	for number in 1 2 3 4 5 ; do \
	    echo "" \
	    echo "TEST ITERATION $$number" ; \
	    make clean; MOD_LEN=1024 \
                    ITERATIONS=1 \
                    T_FINAL=1000 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make; \
	done

# Does not work with the simple multiplier due to verilator bitwidth limitations
regression:
	make clean; MOD_LEN=128 \
                    ITERATIONS=20 \
                    T_FINAL=30 \
                    FASTSIM=0 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; MOD_LEN=128 \
                    ITERATIONS=100 \
                    T_FINAL=30 \
                    FASTSIM=0 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; MOD_LEN=256 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=0 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; MOD_LEN=512 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; MOD_LEN=2048 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make


######################################################################
# Other targets

show-config:
	$(VERILATOR) -V

maintainer-copy::
clean mostlyclean distclean maintainer-clean::
	-rm -rf obj_dir logs *.log *.dmp *.vpd coverage.dat core mem
	-rm -rf msuconfig.vh
