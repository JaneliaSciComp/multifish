#!/bin/bash
#
# This script downloads all the necessary data and runs the end-to-end pipeline on a small demo data set.
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

verify_md5=true
data_size="small"
files_txt="demo_${data_size}.txt"
fixed_round="LHA3_R3_${data_size}"
moving_rounds="LHA3_R5_${data_size}"

if [[ "$#" -lt 1 ]]; then
    echo "Usage: $0 <data dir>"
    echo ""
    echo "This is a demonstration of the EASI-FISH analysis pipeline on a small sized cutout of the LHA3 data set. "
    echo "The data dir will be created, data will be downloaded there based on $files_txt, and the "
    echo "full end-to-end pipeline will run on these data, producing output in the specified data dir."
    echo ""
    exit 1
fi

datadir=$(realpath $1)
shift # eat the first argument so that $@ works later

inputdir=$datadir/inputs
$BASEDIR/data-sets/download_dataset.sh "$BASEDIR/data-sets/$files_txt" "$inputdir" "false"

outputdir=$datadir/outputs
mkdir -p $outputdir

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
        --runtime_opts "-B $BASEDIR -B $datadir -B $TMPDIR" \
        --singularity_cache_dir "$SINGULARITY_CACHEDIR" \
        --workers "1" \
        --worker_cores "16" \
        --gb_per_core "3" \
        --driver_memory "2g" \
        --channels "c0,c1" \
        --stitching_ref "1" \
        --dapi_channel "c1" \
        --spot_extraction_xy_stride "512" \
        --spot_extraction_z_stride "256" \
        --spot_extraction_cpus "1" \
        --spot_extraction_memory "8" \
        --data_dir "$inputdir" \
        --output_dir "$outputdir" \
        --ref_acq "$fixed_round" \
        --acq_names "$fixed_round,$moving_rounds" "$@"
