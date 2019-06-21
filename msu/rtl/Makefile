######################################################################
#
# DESCRIPTION: Verilator Example: Small Makefile
#
# This calls the object directory makefile.  That allows the objects to
# be placed in the "current directory" which simplifies the Makefile.
#
# Copyright 2003-2018 by Wilson Snyder. This program is free software; you can
# redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
#
######################################################################
# Check for sanity to avoid later confusion

ifneq ($(words $(CURDIR)),1)
 $(error Unsupported: GNU Make cannot build in directories containing spaces, build elsewhere: '$(CURDIR)')
endif

######################################################################
# Set up variables

# If $VERILATOR_ROOT isn't in the environment, we assume it is part of a
# package inatall, and verilator is in your path. Otherwise find the
# binary relative to $VERILATOR_ROOT (such as when inside the git sources).
ifeq ($(VERILATOR_ROOT),)
VERILATOR              = verilator
VERILATOR_COVERAGE     = verilator_coverage
else
export VERILATOR_ROOT
VERILATOR              = $(VERILATOR_ROOT)/bin/verilator
VERILATOR_COVERAGE     = $(VERILATOR_ROOT)/bin/verilator_coverage
endif

VERILATOR_FLAGS =
# Generate C++ in executable form
VERILATOR_FLAGS       += -cc --exe
# Generate makefile dependencies (not shown as complicates the Makefile)
#VERILATOR_FLAGS       += -MMD
# Optimize
VERILATOR_FLAGS       += -O2 -x-assign unique
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS       += -Wall
# Make waveforms
VERILATOR_TRACE       ?= 1
ifeq ($(VERILATOR_TRACE), 1)
VERILATOR_FLAGS       += --trace --trace-max-array 256
TRACE_FLAG             = +trace
endif
# Check SystemVerilog assertions
VERILATOR_FLAGS       += --assert
# Generate coverage analysis
#VERILATOR_FLAGS       += --coverage
# Run Verilator in debug mode
#VERILATOR_FLAGS       += --debug
# Add this trace to get a backtrace in gdb
#VERILATOR_FLAGS       += --gdbbt
VERILATOR_FLAGS       += --unroll-count 512


# Test configuration

REDUNDANT_ELEMENTS    ?= 2
NONREDUNDANT_ELEMENTS ?= 8
WORD_LEN              ?= 16
BIT_LEN               ?= 17

ITERATIONS            ?= 25
T_FINAL               ?= 3
MODULUS               ?= 302934307671667531413257853548643485645
FASTSIM               ?= 1

ifeq ($(RANDOM_MODULUS),1)
MODULUS               := $(shell python3 -c \
	  "import random; \
           bits = $(NONREDUNDANT_ELEMENTS)*$(WORD_LEN); \
	   M = random.getrandbits(bits); \
           print(M)")
endif
export RANDOM_MODULUS  = 0

# Overrides to reproduce specific cases
# ITERATIONS             = 1
# T_FINAL                = 30
# MODULUS                = 302934307671667531413257853548643485645
# SQ_IN                  = 0x7ffffff7ffffffffe00000007fffffff

# TODO - Failure 32
# ITERATIONS = 1
# T_FINAL = 2
# NONREDUNDANT_ELEMENTS = 32
# MODULUS = 6489662188004289912380470564448077957325054535910000462604166663459673710886837850185567098610688907939251192940184027313309919696320700640064979438888128
# SQ_IN = 0x3ffffffffffffffc00000000000000000fffffffffffffffffffffffff00000000000ffffffff80000000007fffc0000000000000001ffffffffffffffffffff

# TODO - Failure 128
# ITERATIONS = 1
# T_FINAL = 10
# NONREDUNDANT_ELEMENTS = 128
# MODULUS = 9377944221571685634155357309238201353523714494933203932192352610373185905160064191380814163563653465686686344569948132435768764189230283870831379273286538073257936156915196745293608951123906426669343509495359436534714767355508167485174462490387748891786824058464058759514090422733587163281784566205124153235051703550025891216469399946549380070025504308122753979231888712348434628534163045096998571026286859992004518389268564973163318230346906823917015138015136534425282323916197448591565660862677175296696705791983908960387617248409752260394512393068089040746777040892828872978879414544318732112296166363704634142810
# SQ_IN = 0x3ffffffffffffffffffffffffffffffff80000000000000000000000000000000000000000000000000000000000000000000000000000000000001fffffffffffffffffffffffffffffffffffffe0000000000000000000000000000000000000000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007fffc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

# TODO - Failure 32
# FASTSIM = 0
# ITERATIONS = 1
# T_FINAL = 2
# NONREDUNDANT_ELEMENTS = 32
# MODULUS = 7768469875464925610083298842934371849153968918356431926667307316978392256791686380024303418445630700092459447571923977749121719620452393869593114711317147
# SQ_IN = 0x3ffffffffffffffffffffff80000000000000000000000007fffe00fffffffffffffffffffc00000000000000000000000000007fffffffffffffffff8000000

ifdef SQ_IN
SQ_IN_FLAG             = -s $(SQ_IN)
endif
ifeq ($(RRANDOM), 1)
RRANDOM_FLAG           = -1
endif
ifeq ($(FASTSIM), 1)
VERILATOR_FLAGS       += -DFASTSIM=1
endif

VERILATOR_FLAGS       += -DNONREDUNDANT_ELEMENTS_DEF=$(NONREDUNDANT_ELEMENTS) \
                         -DREDUNDANT_ELEMENTS_DEF=$(REDUNDANT_ELEMENTS) \
                         -DWORD_LEN=$(WORD_LEN) -DBIT_LEN=$(BIT_LEN)
VERILATOR_FLAGS       += -CFLAGS '-I../../sw -Wall -std=c++11'
VERILATOR_FLAGS       += ../sw/MSU.cpp ../sw/MSUVerilator.cpp

MODSQR_PATH            = $(realpath ../../modular_square/rtl)

######################################################################
default: run

run:
	@echo
	@echo "-- Large Integer Modular Squaring"

	@echo
	@echo "-- GENERATE LUTs -----------------"
	mkdir -p obj_dir
	cd obj_dir && $(MODSQR_PATH)/gen_reduction_lut.py \
                          --wordlen $(WORD_LEN) \
                          --redundant $(REDUNDANT_ELEMENTS) \
                          --nonredundant $(NONREDUNDANT_ELEMENTS) \
                          --modulus $(MODULUS)

	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) $(VERILATOR_FLAGS) -f input.vc msu_tb.sv ../sw/main.cpp

	@echo
	@echo "-- COMPILE -----------------"
	LIBS=-lgmp $(MAKE) -j 4 -C obj_dir -f Vmsu_tb.mk

	@echo
	@echo "-- RUN ---------------------"
	@mkdir -p obj_dir/logs
	cd obj_dir && ./Vmsu_tb $(TRACE_FLAG) -i $(ITERATIONS) \
                          -w $(WORD_LEN) \
                          -r $(REDUNDANT_ELEMENTS) \
                          -n $(NONREDUNDANT_ELEMENTS) \
                          -f $(T_FINAL) \
                          -m $(MODULUS) $(RRANDOM_FLAG) $(SQ_IN_FLAG)

#	@echo
#	@echo "-- COVERAGE ----------------"
#	$(VERILATOR_COVERAGE) --annotate logs/annotated logs/coverage.dat

	@echo
	@echo "-- DONE --------------------"
ifeq ($(VERILATOR_TRACE), 1)
	@echo "To see waveforms:"
	@echo "gtkwave logs/vlt_dump.vcd &"
endif
	@echo

regression:
	make clean; NONREDUNDANT_ELEMENTS=8 \
                    ITERATIONS=20 \
                    T_FINAL=30 \
                    FASTSIM=0 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; NONREDUNDANT_ELEMENTS=8 \
                    ITERATIONS=100 \
                    T_FINAL=30 \
                    FASTSIM=0 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; NONREDUNDANT_ELEMENTS=16 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=0 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; NONREDUNDANT_ELEMENTS=32 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    make
	make clean; NONREDUNDANT_ELEMENTS=128 \
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
