#!/bin/bash
#
# This script downloads all the necessary data and runs the end-to-end pipeline on a demo data set.
# 
# It is tuned for a 40 core machine, with 128 GB of RAM. 
#
# Set TMPDIR in your environment before calling this script.
#

DIR=$(cd "$(dirname "$0")"; pwd)
BASEDIR=$(realpath $DIR/..)

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/tmp}"
export SINGULARITY_TMPDIR=$TMPDIR

verify_md5=false
files_txt="demo_files_medium.txt"
fixed_round="LHA3_R3_medium"
moving_rounds="LHA3_R5_medium"

if [[ "$#" -lt 1 ]]; then
    echo "Usage: $0 <data dir>"
    echo ""
    echo "This is a small demonstration of the EASI-FISH analysis pipeline on a cutout of the LHA3 data set. "
    echo "The data dir will be created, data will be downloaded there based on $files_txt, and the "
    echo "full end-to-end pipeline will run on these data, producing output in the specified data dir."
    echo ""
    exit 1
fi

datadir=$(realpath $1)
shift # eat the first argument so that $@ works later

inputdir=$datadir/inputs
$DIR/download_dataset.sh "$DIR/demo_files_medium.txt" "$inputdir" "false"

segmentation_modeldir="$inputdir/model/starfinity"
if [ ! -e $segmentation_modeldir ]; then
    echo "Extracting Starfinity model..."
    unzip -o $inputdir/model.zip -d $inputdir/    
fi
echo "Using Starfinity model: $segmentation_modeldir"

outputdir=$datadir/outputs
mkdir -p $outputdir

#
# Memory Considerations
# =====================
#
# The value of workers*worker_cores*gb_per_core determines the total Spark memory for each acquisition registration. 
# For the demo, two of these need to fit in main memory. The settings below work for a 40 core machine with 128 GB RAM.
#
# Reducing the gb_per_core to 2 reduces total memory consumption from 128GB to 100GB but doubles processing time 
# from 12 min to 23 min.
#

./main.nf \
        --runtime_opts "--nv -B $BASEDIR -B $datadir -B $TMPDIR" \
        --workers 1 \
        --worker_cores 16 \
        --gb_per_core 3 \
        --driver_memory 2g \
        --spark_work_dir "$datadir/spark" \
        --data_dir "$inputdir" \
        --output_dir "$outputdir" \
        --segmentation_model_dir "$segmentation_modeldir" \
        --ref_acq "$fixed_round" \
        --acq_names "$fixed_round,$moving_rounds" "$@"
