---
layout: default
nav_order: 2
---

# Quick Start

## Nextflow Tower Quick Start

The easiest way to use the EASI-FISH pipeline is by running it from the Nextflow Tower web interface. For Janelia users, Nextflow Tower is [available locally](http://nextflow.int.janelia.org) (requires Janelia VPN) and allows us to execute on either the Janelia cluster or AWS cloud. If your institution does not have Nextflow Tower installed, you can use the official [Nextflow Tower](tower.nf) instance to execute on any cloud platform.

## Command-line Quick Start

For tech-savvy users, the pipeline can be invoked from the command-line and runs on any workstation or cluster. The only prerequisites for running this pipeline are [Nextflow](https://www.nextflow.io) (version 20.10.0 or greater) and [Singularity](https://sylabs.io) (version 3.5 or greater). If you are running on an HPC cluster, ask your system administrator to install Singularity on all the cluster nodes. Singularity is a popular HPC containerization tool, so many institutional clusters already support it.

To [install Nextflow](https://www.nextflow.io/docs/latest/getstarted.html):

    curl -s https://get.nextflow.io | bash 

Alternatively, you can install it as a conda package:

    conda create --name multifish -c bioconda nextflow

To [install Singularity](https://sylabs.io/guides/3.7/admin-guide/installation.html) on CentOS Linux:

    sudo yum install singularity

Clone this repository with the following command:

    git clone https://github.com/JaneliaSciComp/multifish.git

Before running the pipeline for the first time, run setup to pull in external dependencies:

    ./setup.sh

You can now launch the pipeline using:

    ./main.nf [arguments]

## Demo Data Sets

To get running quickly, there are demo scripts available which download EASI-FISH example data and run the full pipeline. You can analyze the smallest data set like this:

    ./examples/demo_small.sh <data dir> [arguments]

The `data dir` is the path where you want to store the data and analysis results. You can add additional arguments to skip steps previously completed or add monitoring with [Nextflow Tower](https://tower.nf). See below for additional details about the argument usage.

The script will download a small [demo data set](https://doi.org/10.25378/janelia.c.5276708.v1) and run the full analysis pipeline. It is tuned for a 40 core machine with 128 GB of RAM. If your compute resources are different, you may need to edit the script to change the parameters to suit your environment.

After the pipeline runs, you can expect to find 82 GB in the data dir:

    23G     /opt/demo_small/inputs
    58G     /opt/demo_small/outputs
    525M    /opt/demo_small/spark

There is also a `demo_medium.sh` with larger data that requires 209 GB in total:

    65G     /opt/demo_medium/inputs
    145G    /opt/demo_medium/outputs
    665M    /opt/demo_medium/spark
