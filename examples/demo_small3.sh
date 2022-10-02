#!/bin/bash
#
# This script downloads all the necessary data and runs the end-to-end pipeline on a small demo data set.
# 
# It takes about 2 hours to run.
#
# The parameters below are tuned for a 40 core machine, with 128 GB of RAM. 
#
# If your /tmp directory is on a filesystem with less than 10 GB of space, you can set the TMPDIR variable
# in your environment before calling this script, for example, to use your /opt for all file access:
#
#   TMPDIR=/opt/tmp ./examples/demo_small.sh /opt/demo
#

DIR=$(cd "$(dirname "$0")"; pwd)
BASEDIR=$(realpath $DIR/..)

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/tmp}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-$TMPDIR}"
export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$TMPDIR/singularity}"
mkdir -p $TMPDIR
mkdir -p $SINGULARITY_TMPDIR
mkdir -p $SINGULARITY_CACHEDIR

if [[ "$#" -lt 1 ]]; then
    echo "Usage: $0 <data dir>"
    echo ""
    echo "This is a demonstration of the EASI-FISH analysis pipeline on a small sized cutout of the LHA3 data set. "
    echo "The data dir will be created, data will be downloaded there based on the manifest, and the "
    echo "full end-to-end pipeline will run on these data, producing output in the specified data dir."
    echo ""
    exit 1
fi

datadir=$(realpath $1)
shift # eat the first argument so that $@ works later

#
# Memory Considerations
# =====================
# 
# The value of workers*worker_cores*gb_per_core determines the total Spark memory for each acquisition registration. 
# For the demo, two of these need to fit in main memory. The settings below work for a 40 core machine with 128 GB RAM.
#
# Reducing the gb_per_core to 2 reduces total memory consumption but doubles processing time.
#

./main.nf \
    -params-file "./examples/demo_small3.json" \
    --runtime_opts "-B $datadir -B $TMPDIR" \
    --shared_work_dir "$datadir" "$@"

