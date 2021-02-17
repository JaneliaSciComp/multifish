#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)
BASEDIR=$(realpath $DIR/..)

verify_md5=true
files_txt="demo_files_small.txt"
fixed_round="LHA3_R3_small"
moving_rounds="LHA3_R5_small"

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

./main.nf \
        --runtime_opts "--nv -B $BASEDIR -B $datadir" \
        --workers 4 \
        --worker_cores 4 \
        --driver_memory 15g \
        --spark_work_dir "$datadir/spark" \
        --stitching_app "$stitching_app" \
        --block_size "128,128,32" \
        --retile_z_size "32" \
        --registration_z_stride "16" \
        --registration_z_overlap "8" \
        --spot_extraction_z_stride "16" \
        --spot_extraction_z_overlap "8" \
        --data_dir "$inputdir" \
        --output_dir "$outputdir" \
        --segmentation_model_dir "$segmentation_modeldir" \
        --ref_acq "$fixed_round" \
        --stitch_acq_names "$fixed_round,$moving_rounds" \
        --registration_moving_acq_names "$moving_rounds" "$@"
