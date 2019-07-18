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
