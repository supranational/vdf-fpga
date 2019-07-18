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


# Default test configuration

REDUNDANT_ELEMENTS    ?= 2
NONREDUNDANT_ELEMENTS ?= 8
NUM_URAMS             ?= 2
WORD_LEN              ?= 16
BIT_LEN               ?= 17

ITERATIONS            ?= 25
T_FINAL               ?= 3
FASTSIM               ?= 1
INTERMEDIATES         ?= 0

include ./modulus.mk


# Overrides to reproduce specific cases
# ITERATIONS = 1
# T_FINAL = 30
# NONREDUNDANT_ELEMENTS = 8
# MODULUS = 302934307671667531413257853548643485645
# SQ_IN = 0x45558c7335696741d41c91186caf806b
# NUM_URAMS = 1

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
                          --urams $(NUM_URAMS) \
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
                          -u $(NUM_URAMS) \
                          -t $(INTERMEDIATES) \
                          -f $(T_FINAL) \
                          -m $(MODULUS) $(RRANDOM_FLAG) $(SQ_IN_FLAG) \
                          -d "." \
                          -e

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

# Run multiple tests with a random modulus
judge:
	for number in 1 2 3 4 5 ; do \
	    echo "" \
	    echo "TEST ITERATION $$number" ; \
	    make clean; NONREDUNDANT_ELEMENTS=64 \
                    ITERATIONS=1 \
                    T_FINAL=1000 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    NUM_URAMS=0 \
                    make; \
	done

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
                    NUM_URAMS=2 \
                    make
	make clean; NONREDUNDANT_ELEMENTS=32 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    NUM_URAMS=1 \
                    make
	make clean; NONREDUNDANT_ELEMENTS=128 \
                    ITERATIONS=10 \
                    T_FINAL=10 \
                    FASTSIM=1 \
                    RANDOM_MODULUS=1 \
                    RRANDOM=1 \
                    VERILATOR_TRACE=0 \
                    NUM_URAMS=0 \
                    make


######################################################################
# Other targets

show-config:
	$(VERILATOR) -V

maintainer-copy::
clean mostlyclean distclean maintainer-clean::
	-rm -rf obj_dir logs *.log *.dmp *.vpd coverage.dat core mem
