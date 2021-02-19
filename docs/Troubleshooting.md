## Troubleshooting

### Temporary Files

The pipeline downloads Docker containers and converts them into Singularity Image Format prior to execution. In addition, other parts of the pipeline also use the temp directory while running, for example for MATLAB's MCR_CACHE_ROOT.

If the filesystem containing your /tmp directories does not have sufficient space for downloading and extracting the Docker containers, you will need to point  `TMPDIR` and/or `SINGULARITY_TMPDIR` to an alternate location, e.g.

    export TMPDIR=/scratch/tmp
    export SINGULARITY_TMPDIR=/scratch/tmp

If you do this, make sure to mount this directory into the containers using the `-B` option:

    --runtime_opts "-B $TMPDIR"

### Cached SIF Files

By default, all Singularity images (SIF-format .img files) are cached by the pipeline in ~/.singularity_cache. This directory must be accessible from all cluster nodes. You can customize this directory by setting `singularity.cacheDir` in the `nextflow.config` file.
