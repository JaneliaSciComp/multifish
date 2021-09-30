---
layout: default
parent: Platforms
nav_order: 2
---

# IBM Platform LSF

To run the pipeline on a compute cluster, Singularity must be installed on all the cluster nodes you are using. Singularity is a popular HPC containerization tool, so many institutional clusters already support it. If not, ask your system administrator to [install it](https://sylabs.io/guides/3.1/user-guide/installation.html).

To run on an LSF cluster, simply specify the **lsf** profile:

    ./main.nf -profile lsf

You can also set arbitrary `bsub` flags with the lsf_opts parameter, for example:

    ./main.nf -profile lsf --lsf_opts "-P project_code" [arguments]

The **lsf** profile is optimized for Janelia's compute cluster and may need modifications to run elsewhere. You can find it in the [nextflow.config](https://github.com/JaneliaSciComp/multifish/blob/master/nextflow.config) file.

Usage examples are available in the [examples](https://github.com/JaneliaSciComp/multifish/blob/master/examples) directory.
