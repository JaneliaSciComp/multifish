---
layout: default
parent: Platforms
nav_order: 4
---

# AWS Batch

Most users wanting to run on AWS should use the [Nextflow Tower instructions](NextflowTower.md). This page describes a manual approach to create a custom AWS environment for advanced users.

We need two AWSBatch compute environments - one for the tasks that only require CPU and one for the tasks that require GPU. In addition to that we need an EFS volume that will be mounted on all EC2 instances used for running jobs.

## Create the AWS EFS Volume and Access Point

This can be done from the AWS console following [these instructions](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html) or if you have experience with AWS-CLI and you prefer that, you can follow [these instructions](https://docs.aws.amazon.com/efs/latest/ug/wt1-getting-started.html).

When you select the VPC cloud make sure that you select one that is accessible by the EC2 instance as well so that you can mount the access point on it. Also remember the generated FileSystemId when you created the EFS and the path that you used for the access point.

## Create the AMI instances

For creating the AMI instances the 2 environments launch 2 EC2 instances from the following public AMIs:

* `ami-0cce120e74c5100d4` for the CPU compute environment
* `ami-0c885adf297004c8c` for the GPU compute environment
* for other regions check <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html> for the ECS optimized or ECS GPU optimized AMI IDs

Once the instances are up and running ssh into them and run the following instructions:

```bash
sudo yum update -y
sudo amazon-linux-extras install -y epel
sudo yum install -y yum-utils pciutils wget fuse s3fs-fuse bzip2 nfs-utils

# install aws-cli using miniconda
wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -f -p $HOME/miniconda
$HOME/miniconda/bin/conda install -c conda-forge -y awscli
rm Miniconda3-latest-Linux-x86_64.sh

# change fs-509941e4:/ to your EFS volume ID and access point
sudo mkdir /efs-multifish
sudo echo -e 'fs-509941e4:/\t/efs-multifish\tefs\trw,_netdev\t0\t0' | sudo tee -a /etc/fstab

# change janelia-nextflow-demo:/multifish to your bucket and folder
sudo mkdir /s3-multifish
sudo echo -e 's3fs#janelia-nextflow-demo:/multifish\t/s3-multifish\tfuse\trw,_netdev,use_path_request_style,allow_other,umask=0000,iam_role=auto,kernel_cache,max_background=1000,max_stat_cache_size=100000,multipart_size=52,parallel_count=30,dbglevel=warn\t0\t0' | sudo tee -a /etc/fstab

sudo mount –a
```

For the GPU instance we also need to set the default docker runtime to `nvidia`

```bash
# /usr/libexec/docker/docker-setup-runtimes.sh already exists so you can simply edit it 
# and add the `echo -n "--default-runtime nvidia "` line
sudo cat > /usr/libexec/docker/docker-setup-runtimes.sh <<EOF
#!/bin/sh
{
    echo -n "DOCKER_ADD_RUNTIMES=\""
    for file in /etc/docker-runtimes.d/*; do
        [ -f "$file" ] && [ -x "$file" ] && echo -n "--add-runtime $(basename "$file")=$file "
    done
    echo -n "--default-runtime nvidia "
    echo "\""
} > /run/docker/runtimes.env
EOF
```

The last step before you save your AMI instances stop the ECS service:

```bash
sudo systemctl stop ecs
sudo rm -rf /var/lib/ecs/data/agent.db
```

Once you have the AMI IDs set them in the 'serverless.yml' file as well as with other custom properties.

## Deploy the AWS batch environment

The AWS batch is deployed using serverless so first install serverless by simply running:

```bash
npm install
```

and then (change the stage to the appropriate value):

```bash
npm run sls -- deploy --stage dev
```

## Copy the data to AWS S3

The jobs will get the raw data from AWS S3 but all the results and the temporary files will be generated to the EFS volume.

```bash
aws s3 cp /nrs/multifish/Pipeline/Examples/subset/ss s3://janelia-nextflow-demo:/multifish/small --recursive
aws s3 cp /nrs/multifish/Pipeline/segmentation/starfinity/model/starfinity_augment_all s3://janelia-nextflow-demo:/multifish/model
```

## Running the pipeline

Here's an example of a script:

```bash
#!/bin/bash

export TOWER_ACCESS_TOKEN=<your nextflow tower acccess token>

nextflow run main.nf \
    -with-tower "http://nextflow.int.janelia.org/api" \
    -profile awsbatch \
    -w s3://janelia-nextflow-demo/multifish/work \
    --workers 1 \
    --worker_cores 16 \
    --wait_for_spark_timeout_seconds 3600 \
    --sleep_between_timeout_checks_seconds 2 \
    --gb_per_core 4 \
    --channels "c0,c1" \
    --stitching_ref 1 \
    --dapi_channel c1 \
    --segmentation_cpus 1 \
    --spot_extraction_xy_stride 512 \
    --spot_extraction_z_stride 256 \
    --spot_extraction_cpus 2 \
    --spot_extraction_memory "8 G" \
    --spark_local_dir "/tmp" \
    --spark_work_dir "/efs-multifish/spark/small" \
    --data_dir "/s3-multifish/small" \
    --output_dir "/efs-multifish/results/small" \
    --acq_names "LHA3_R3_small,LHA3_R5_small" \
    --ref_acq "LHA3_R3_small" \
    --segmentation_model_dir "/s3-multifish/models/starfinity-model"
```
