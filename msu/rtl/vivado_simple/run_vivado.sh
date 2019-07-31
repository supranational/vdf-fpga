#!/bin/bash

set -e

# Configuration
export MOD_LEN=1024
export SIMPLE_SQ=1
MODEL=msu

# Set current directory to the location of this script
SCRIPT=$(dirname "$0")
SCRIPTPATH=$(realpath "$SCRIPT")
cd $SCRIPTPATH

# Clean up the msuconfig file in rtl so vivado doesn't choose it
# (why is there no way to configure the vivado include path?)
rm -f ../msuconfig.vh

# Generate a test
../gen_test.py -c -s $MOD_LEN

# Generate the Vivado project
if [ ! -d msu ]; then
    echo "Generating vivado project"
    ./generate.sh
fi

# Update the project directory to the current dir
#sed 's@\(Project [^ ]\+ [^ ]\+ Path="\)[^\\"]\+@\1'$SCRIPTPATH/$MODEL.xpr'@' $MODEL.xpr > $MODEL.xpr_new
#mv $MODEL.xpr_new $MODEL.xpr

cd msu
vivado $MODEL.xpr &
