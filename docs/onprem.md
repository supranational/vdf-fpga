# SDAccel On-Premise

It's possible to perform hardware emulation and synthesis on-premise using the flow defined by AWS. 

The steps to enable an on-premise are described here: <https://github.com/aws/aws-fpga/blob/master/SDAccel/docs/On_Premises_Development_Steps.md>.

You will need a license for the vu9p in Vivado and for SDAccel. Xilinx offers trial licenses on their website. The licenses should be loaded through the license manager, which is accessed from the Vivado Help menu. 

Host requirements: 32GB of memory is preferred though 16GB of memory should be sufficient. Single threaded performance is the main determinant of runtime. 

## Ubuntu 18

While Ubuntu 18 is not officially supported, the on-premise flow can be made to work with a few additional changes after installing SDAccel.

```
# Link to the OS installed version of libstdc++:
cd /tools/Xilinx/SDx/2018.3/lib/lnx64.o/Default/
mv libstdc++.so.6 libstdc++.so.6_orig
ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6

cd /tools/Xilinx/SDx/2018.3/lib/lnx64.o/Default/
mv libstdc++.so.6 libstdc++.so.6_orig
ln -s /usr/lib/x86_64-linux-gnu/libstdc++.so.6

# After the changes above this should report "ERROR: no card found"
/opt/xilinx/xrt/bin/xbutil validate

# Some of the python scripts reference /bin/env
cd /bin
sudo ln -s /usr/bin/env
```

## helloworld

The `helloworld_ocl` example should now successfully complete:
```
source ./msu/scripts/sdaccel_env.sh
cd $AWS_FPGA_REPO_DIR/SDAccel/examples/xilinx/getting_started/host/helloworld_ocl

# in Makefile, change DEVICE to:
DEVICE := $(AWS_PLATFORM)

make cleanall; make TARGETS=sw_emu DEVICES=$AWS_PLATFORM check
```

You can now follow the hardware emulation and synthesis flows described in [aws_f1](docs/aws_f1.md).

To register the image built from on-premise synthesis first copy the `msu/rtl/obj/xclbin/vdf.hw.xilinx_aws-vu9p-f1-04261818_dynamic_5_0.xclbin` and `host` files to an AWS F1 instance, then run `create_sdaccel_afi.sh`.
