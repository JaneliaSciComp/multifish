---
layout: default
nav_order: 30
---

# Troubleshooting

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
