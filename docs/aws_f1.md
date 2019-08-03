# AWS F1

AWS F1 supports hardware emulation as well as FPGA accelerated execution. 

The typical workflow involves two types of hosts. You will most likely have to submit a request for an instance limit increase. This process is described in the error message if you try to instantiate one of these hosts and your limit is insufficient.
- Development, using a z1d.2xlarge with no attached FPGA
- Accelerated, using a f1.2xlarge with attached FPGA

AWS provides general information for using F1 (<https://github.com/aws/aws-fpga/blob/master/SDAccel/README.md>). 

A distilled down set of instructions specific to this design follows.

**Note that you can also enable AWS F1 hardware emulation and synthesis on-premise. See [SDAccel On-Premise](#sdaccel-on-premise)**

## Host instantiation

We assume some familiarity with the AWS environment. To instantiate a new AWS host for working with the FPGA follow these steps:

1. Login to the AWS page <https://aws.amazon.com/>, go to the EC2 service portal
1. Click on Launch Instance
1. For AMI, go to AWS Marketplace, then search for FPGA
1. Choose FPGA Developer AMI
1. For instance type choose z1d.2xlarge for development, f1.2xlarge for FPGA enabled, then Review and Launch
1. For configuration of the host we recommend:
    1. Increase root disk space by about 20GB for an f1.2xlarge, 60GB for a z1d.2xlarge.
    1. Add a descriptive tag to help track instances and volumes
1. Launch the instance
1. In the EC2 Instances page, select the instance and choose Actions->Connect. This will tell you the instance hostname that you can ssh to. 
    1. Note that for the FPGA Developer AMI the username will be 'centos'
    1. Log in with `ssh centos@HOST`

You may find it convenient to install additional ssh keys for github, etc. 

## Host setup

Some initial setup is required for new F1 hosts. See <https://github.com/aws/aws-fpga/blob/master/SDAccel/README.md> for more detail.

We've encapsulated a typical setup that includes vnc:
```
./msu/scripts/f1_setup.sh
```

You can then optionally start a vncserver if you prefer to work in an X-windows environment:
```
# Start a vncserver
vncserver
```

Connect using ssh to tunnel the vnc port:
```
ssh -L 5908:localhost:5901 centos@HOST
```

And view it locally:
```
vncviewer :8
```

Once you have vnc up run vncconfig to enable copy/paste:
```
vncconfig &
```

## Hardware Emulation

To build and run a test in hardware emulation:
```
source ./msu/scripts/sdaccel_env.sh
cd msu
make clean
make hw_emu
```

Rerunning without cleaning the build will retain the hardware emulation (hardware) portion while rebuilding and executing the host (software) portion.

Tracing is enabled by default in the hw_emu run. To view the resulting waveforms run:
```
vivado -source open_waves.tcl
```

## Hardware Synthesis 

Synthesis and Place&Route compile the design from RTL into a bitstream that can be loaded on the FPGA. This step takes 1-3 hours depending on complexity of the design, host speed, synthesis targets, etc. 

You can enable a **faster run** by relaxing the kernel frequency (search for kernel_frequency in the Makefile) or building a smaller multiplier (comment out 1024b, uncomment 128b in the Makefile). This is often convenient when trying things out.

```
source ./msu/scripts/sdaccel_env.sh
cd msu
make clean
make hw
```

Once synthesis successfully completes you can register the new image to process it for running on FPGA hardware. Follow the instructions in <https://github.com/aws/aws-fpga/blob/master/SDAccel/docs/Setup_AWS_CLI_and_S3_Bucket.md> to setup an S3 bucket. This only needs to be done once. We assume a bucket name 'vdfsn' but you will need to change this to match your bucket name. Once that is done run the following:

```
# Configure AWS credentials. You should only need to do this once on a given
# host
#    AWS Access Key ID [None]: XXXXXX
#    AWS Secret Access Key [None]: XXXXXX
#    Default region name [None]: us-east-1
#    Default output format [None]: json
aws configure

# Register the new bitstream
# Update S3_BUCKET in Makefile.sdaccel to reflect the name of your bucket.
cd msu/rtl/sdaccel
make to_f1

# Check status using the afi_id from the last step. It should say 
# pending for about 30 minutes, then available.
cat *afi_id.txt
aws ec2 describe-fpga-images --fpga-image-ids afi-XXXXXXXXXXXX

# Copy the required files to an FPGA enabled host for execution:
HOST=xxxx # Your F1 hostname here
scp obj/to_f1.tar.gz centos@$HOST:.
```

## FPGA Execution

Once you have synthesized a bitstream, registered it using `create_sdaccel_afi.sh`, describe-fpga-image reports available, and copied the necessary files to an f1 machine you are ready to execute on the FPGA.

Currently debug mode is required due to a known AWS issue. Create an `sdaccel.ini` file in the same directory you will be running from: 
```
cat <<EOF > sdaccel.ini 
[Debug]
profile=true
EOF
```

Execute the host driver code. This will automatically load the image referenced by the awsxclbin file onto the FPGA. 
```
tar xf to_f1.tar.gz
sudo su
source $AWS_FPGA_REPO_DIR/sdaccel_runtime_setup.sh 

# Run a short test and verify the result in software
./host -e -f 100

# Run a billion iterations starting with an input of 2
./host -s 0x2 -f 1073741824
```

The expected result of 2^2^2^30 using the default 1k (64 coefficient) modulus in the Makefile is:
`9782776834334634490446343758704728706980122657033141222406929631982781114105293252444979173994924549755313289718816652420124314107449156688222852673024696927113240716169907514261823484008194829047317452425855361884165852504086556390349991640188347831084926001670580437428161157316196941905575574310934275893`
