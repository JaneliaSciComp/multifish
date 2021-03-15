# Running on AWS EC2

Although Nextflow supports AWS Batch as a target, this pipeline doesn't support that mode of execution due to the fact we currently use a shared file system instead of `publishDir` to copy data for each task. 

The pipeline can be run manually on a single large EC2 instance as follows.

## Prerequisites

You need to have AWS access, which is outside the scope of this guide. Refer to AWS documentation to set up your AWS environment.

## Launch an EC2 instance

https://docs.aws.amazon.com/quickstarts/latest/vmlaunch/step-1-launch-instance.html

## SSH to your instance

    ssh -i "your_key.pem" ec2-user@<public IP>

## Mount EBS drive

Refer to the [EC2 User Guide on EBS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html]) to create and mount an EBS drive large enough for your data set.

After creating the EBS drive, mounting will look something like this:

    sudo mkfs -t xfs /dev/sdb
    sudo mkdir /data
    sudo mount /dev/sdb /data

## Install Nextflow

The default Amazon 2 image does not include Java, so you will need to instal that before installing Nextflow:

    sudo amazon-linux-extras enable corretto8
    sudo yum install java-1.8.0-amazon-corretto-devel
    curl -s https://get.nextflow.io | bash
    sudo mv nextflow /usr/local/bin/

## Install Singularity

To install Singularity, install EPEL first:

    sudo amazon-linux-extras install epel
    sudo yum install -y singularity-runtime singularity

## Run Pipeline

Log into https://tower.nf and follow instructions for setting up TOKEN variable in the ssh session. Now you can run the pipeline. For example, to run the demo:

    git clone https://github.com/JaneliaSciComp/multifish.git
    ./setup.sh
    TMDIR=/data/tmp ./examples/demo_small.sh /data/demo -with-tower

## Shutdown Instance

Remember to shutdown your EC2 instance after the pipeline is complete, to avoid incurring extra charges.
