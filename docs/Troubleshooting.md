---
layout: default
nav_order: 30
---

# Troubleshooting

## Common Errors

### Exit status 130/137

These exit codes indicate that the task ran out of memory. You need to increase the memory setting for the task.

When running with Docker (e.g. on AWS) you will see code 137. On IBM Platform LSF it's exit code 130. 

For example, if a *registration:stitch* task runs out of memory, you will need to increase the corresponding `registration_stitch_memory` parameter, e.g. to `30 G`. 

As a special case, the Janelia LSF Cluster does not respect the memory settings. Instead you need to increase the number of CPUs for the task. CPUs are mapped to slots at Janelia, and each slot gives you an additional 15 GB of memory.

## Temporary Files

The pipeline produces various temporary files during processing, and one common problem is running out of space for these files.

### Container Builds

The pipeline downloads Docker containers and converts them into Singularity Image Format prior to execution. By default, this uses the /tmp on your system. If the filesystem containing your /tmp directories does not have sufficient space for downloading and extracting the Docker containers, you will need to point  `SINGULARITY_TMPDIR` to an alternate location, e.g.

    export SINGULARITY_TMPDIR=/scratch/tmp

If you do this, make sure to mount this directory into the containers using the `-B` option:

    --runtime_opts "-B $TMPDIR"

### Cached SIF Files

By default, all Singularity images (SIF-format .img files) are cached by the pipeline in ~/.singularity_cache. The main pipeline process will download these files before launching any jobs, so this directory should be accessible from all cluster nodes. You can customize this path by setting the `--singularity_cache_dir` parameter.

### MATLAB cache

The Airfinity spot extraction module must temporarily extract MATLAB code before each job is run. This uses the process directory by default (a unique path inside `-workDir`) but it can be overriden using `--local_scratch_dir`.
