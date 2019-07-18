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

############################################################################
# Multiplier configuration
############################################################################

SIMPLE_SQ             ?= 0
ifeq ($(SIMPLE_SQ), 1)
MOD_LEN               ?= 128
else
MOD_LEN               ?= 1024
endif

# 1 - Connect the testbench directly to the squaring circuit
# 0 - Connect the testbench directly to the MSU
DIRECT_TB             ?= 0

# Constants for the Ozturk multiplier
REDUNDANT_ELEMENTS     = 2
NONREDUNDANT_ELEMENTS ?= $(shell expr $(MOD_LEN) \/ $(WORD_LEN))
NUM_ELEMENTS           = $(shell expr $(NONREDUNDANT_ELEMENTS) \+ \
	                              $(REDUNDANT_ELEMENTS))
WORD_LEN               = 16
BIT_LEN                = 17

ifeq ($(SIMPLE_SQ), 1)
SQ_IN_BITS             = $(MOD_LEN)
SQ_OUT_BITS            = $(MOD_LEN)
else
SQ_IN_BITS             = $(MOD_LEN)
SQ_OUT_BITS            = $(shell expr $(NUM_ELEMENTS) \* $(WORD_LEN) \* 2)
endif
