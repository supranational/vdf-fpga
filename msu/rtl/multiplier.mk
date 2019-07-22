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

# Default modulus for various sizes
ifndef MODULUS
ifeq ($(NONREDUNDANT_ELEMENTS), 1)
MODULUS = 49088
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 2)
MODULUS = 1319797480
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 4)
MODULUS = 10290524089509967236
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 8)
MODULUS = 302934307671667531413257853548643485645
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 16)
MODULUS = 33025623512261490103902707258419309725034860259537403375815092309878324079655
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 32)
MODULUS = 6489662188004289912380470564448077957325054535910000462604166663459673710886837850185567098610688907939251192940184027313309919696320700640064979438888128
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 64)
MODULUS = 124066695684124741398798927404814432744698427125735684128131855064976895337309138910015071214657674309443149407457493434579063840841220334555160125016331040933690674569571217337630239191517205721310197608387239846364360850220896772964978569683229449266819903414117058030106528073928633017118689826625594484331
endif
ifeq ($(NONREDUNDANT_ELEMENTS), 128)
MODULUS = 9377944221571685634155357309238201353523714494933203932192352610373185905160064191380814163563653465686686344569948132435768764189230283870831379273286538073257936156915196745293608951123906426669343509495359436534714767355508167485174462490387748891786824058464058759514090422733587163281784566205124153235051703550025891216469399946549380070025504308122753979231888712348434628534163045096998571026286859992004518389268564973163318230346906823917015138015136534425282323916197448591565660862677175296696705791983908960387617248409752260394512393068089040746777040892828872978879414544318732112296166363704634142810
endif
endif

ifeq ($(RANDOM_MODULUS),1)
MODULUS               := $(shell python3 -c \
	  "import random; \
           bits = $(NONREDUNDANT_ELEMENTS)*$(WORD_LEN); \
	   M = random.getrandbits(bits); \
           print(M)")
endif
export RANDOM_MODULUS  = 0

# Configure MSU parameters. These are included through vdf_kernel.sv
msuconfig.vh:
	echo "\`define SQ_IN_BITS_DEF $(SQ_IN_BITS)" \
              > msuconfig.vh
	echo "\`define SQ_OUT_BITS_DEF $(SQ_OUT_BITS)" \
              >> msuconfig.vh
	echo "\`define MODULUS_DEF $(MOD_LEN)'d$(MODULUS)" \
              >> msuconfig.vh
	echo "\`define MOD_LEN_DEF $(MOD_LEN)" \
              >> msuconfig.vh
ifeq ($(SIMPLE_SQ), 1)
	echo "\`define SIMPLE_SQ $(SIMPLE_SQ)" \
              >> msuconfig.vh
endif

mem/reduction_lut_000.dat: 
	mkdir -p mem
	cd mem && $(MODSQR_DIR)/rtl/gen_reduction_lut.py \
                          --nonredundant $(NONREDUNDANT_ELEMENTS) \
                          --modulus $(MODULUS)
