#!/bin/bash
#
# This script downloads all the necessary data and runs the end-to-end pipeline on a demo data set.
# 

DIR=$(cd "$(dirname "$0")"; pwd)
BASEDIR=$(realpath $DIR/..)

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR=/opt/tmp
export SINGULARITY_TMPDIR=$TMPDIR

verify_md5=true
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
mkdir -p $inputdir

while read -r file md5 url ; do
    filepath=$inputdir/$file
    if [ ! -e $filepath ]; then
        echo "Downloading: $file"
        curl -L $url -o $filepath
    fi
    if [ "$verify_md5" = true ]; then 
        if md5sum --status -c <<< "$md5 $filepath"; then
            echo "File checksum verified: $file"
        else
            echo "Checksum failed for $file"
            exit 1
        fi
    fi
done < "$DIR/$files_txt"

segmentation_modeldir="$inputdir/model/starfinity"
if [ ! -e $segmentation_modeldir ]; then
    echo "Extracting Starfinity model..."
    unzip -o $inputdir/model.zip -d $inputdir/    
fi
echo "Using Starfinity model: $segmentation_modeldir"

stitching_app=`ls -t $BASEDIR/external-modules/stitching-spark/target/stitching-spark-*-SNAPSHOT.jar | head -1`
if [ ! -e $stitching_app ]; then 
    echo "Stitching app jar not found. Please run setup.sh to build it first."
fi

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
#
# Data Set Considerations
# =======================
#
# The demo data set is sampled from a larger data set by subsetting in Z. Since the number of slices is less than 64, 
# we need to reduce all of the Z strides and block sizes below to accomodate it. 
#

./main.nf \
        --runtime_opts "--nv -B $BASEDIR -B $datadir -B $TMPDIR" \
        --workers 1 \
        --worker_cores 16 \
        --gb_per_core 3 \
        --driver_memory 2g \
        --spark_work_dir "$datadir/spark" \
        --stitching_app "$stitching_app" \
        --data_dir "$inputdir" \
        --output_dir "$outputdir" \
        --segmentation_model_dir "$segmentation_modeldir" \
        --ref_acq "$fixed_round" \
        --acq_names "$fixed_round,$moving_rounds" "$@"
