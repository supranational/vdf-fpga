#!/bin/bash

# Run this script to setup newly instantiated hosts

# Install simulation dependencies
sudo yum update -y
sudo yum install -y gmp-devel verilator python36

# Install the aws-fpga repo
git clone https://github.com/aws/aws-fpga.git $AWS_FPGA_REPO_DIR;
cd $AWS_FPGA_REPO_DIR && git pull;
source $AWS_FPGA_REPO_DIR/sdaccel_setup.sh

# Install VNC (optional, but provides a richer working environment)
sudo yum -y install tigervnc-server tigervnc-server-minimal
sudo yum -y groupinstall X11
sudo yum --enablerepo=epel -y groups install "Xfce" 
sudo yum -y install kdiff3
sudo yum -y install emacs

cd
mkdir .vnc
cd .vnc
cat <<EOF > xstartup
#!/bin/bash
startxfce4 &
EOF
chmod +x xstartup 

