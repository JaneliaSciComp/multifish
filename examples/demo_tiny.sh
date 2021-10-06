#!/bin/bash
#
# This script downloads all the necessary data and runs the end-to-end pipeline on a small demo data set.
# 
# It takes 20 minutes to run on a 40 core machine with 128 GB of RAM. 
#
# If your /tmp directory is on a filesystem with less than 10 GB of space, you can set the TMPDIR variable
# in your environment before calling this script, for example, to use your /opt for all file access:
#
#   TMPDIR=/opt/tmp ./examples/demo_tiny.sh /opt/demo
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
data_size="tiny"
fixed_round="LHA3_R3_${data_size}"
moving_rounds="LHA3_R5_${data_size}"

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
        --runtime_opts "-B $BASEDIR -B $datadir -B $TMPDIR" \
        --data_manifest "demo_$data_size" \
        --shared_work_dir "$datadir" \
        --stitching_czi_pattern '_V%02d' \
        --workers "1" \
        --worker_cores "12" \
        --gb_per_core "4" \
        --driver_memory "1g" \
        --channels "c0,c1" \
        --dapi_channel "c1" \
        --stitching_block_size "1024,1024,256" \
        --retile_z_size "128" \
        --registration_xy_stride "512" \
        --registration_z_stride "64" \
        --registration_xy_overlap "0" \
        --registration_z_overlap "0" \
        --aff_scale "s1" \
        --def_scale "s2" \
        --segmentation_cpus "8" \
        --segmentation_memory "2 G" \
        --spot_extraction_xy_stride "512" \
        --spot_extraction_z_stride "128" \
        --spot_extraction_xy_overlap "32" \
        --spot_extraction_z_overlap "32" \
        --spot_extraction_cpus "1" \
        --spot_extraction_memory "2" \
        --aff_scale_transform_memory "5 G" \
        --def_scale_transform_memory "5 G" \
        --deform_memory "5 G" \
        --registration_stitch_memory "5 G" \
        --registration_transform_memory "5 G" \
        --warp_spots_cpus "4" \
        --warp_spots_memory "8 G" \
        --ref_acq "$fixed_round" \
        --acq_names "$fixed_round,$moving_rounds" "$@"
