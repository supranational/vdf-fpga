#!/bin/bash

# Configuration
export MOD_LEN=1024
MODEL=msu
OBJ=../sdaccel/obj_vivado

# Set current directory to the location of this script
SCRIPT=$(dirname "$0")
SCRIPTPATH=$(realpath "$SCRIPT")
cd $SCRIPTPATH

# Clean up the msuconfig file in rtl so vivado doesn't choose it
# (why is there no way to configure the vivado include path?)
rm -f ../msuconfig.vh

# Build dependencies
mkdir -p ${MODEL}.srcs
rm -fr ${OBJ}
mkdir -p ${OBJ}

# Delete the any old files first to ensure they are up to date
TARGETS="msuconfig.vh mem/reduction_lut_000.dat"
make -C ${OBJ} -f ../Makefile.sdaccel ${TARGETS}

# Copy the ROM files into the src directory.
cp     ${OBJ}/msuconfig.vh ${MODEL}.srcs
cp -r  ${OBJ}/mem ${MODEL}.srcs
rm -fr ${OBJ}

# Update the project directory to the current dir
sed 's@\(Project [^ ]\+ [^ ]\+ Path="\)[^\\"]\+@\1'$SCRIPTPATH/$MODEL.xpr'@' $MODEL.xpr > $MODEL.xpr_new
mv $MODEL.xpr_new $MODEL.xpr

vivado $MODEL.xpr&
