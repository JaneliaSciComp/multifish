#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)

FILES_TXT="$DIR/demo_files_small.txt"
verify_md5=true
fixed_round="LHA3_R3_small"
moving_rounds="LHA3_R5_small"

if [[ "$#" -lt 1 ]]; then
    echo "Usage: $0 <data dir>"
    echo "  This is a small demonstration of the EASI-FISH analysis pipeline on a cutout of the LHA3 data set. "
    echo "  The data dir will be created, data will be downloaded there based on $FILE_TXT, and the analysis will run."
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
        curl -sL $url -o $filepath
    fi
    if [ "$verify_md5" = true ]; then 
        if md5sum --status -c <<< "$md5 $filepath"; then
            echo "File checksum verified: $file"
        else
            echo "Checksum failed for $file"
            exit 1
        fi
    fi
done < "$FILES_TXT"

# TODO: download segmentation model?
segmentation_modeldir="/nrs/scicompsoft/goinac/multifish/models/starfinity-model"

outputdir=$datadir/outputs
mkdir -p $outputdir

#-profile localsingularity \
./main.nf \
        -profile lsf \
        --lsf_opts "-P multifish" \
        --runtime_opts "--nv -B $PWD -B $datadir" \
        --workers 4 \
        --worker_cores 4 \
        --driver_memory 15g \
        --spark_work_dir "$datadir/spark" \
        --stitching_app "$PWD/external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --data_dir "$inputdir" \
        --output_dir "$outputdir" \
        --segmentation_model_dir "$segmentation_modeldir" \
        --ref_acq "${fixed_round}" \
        --stitch_acq_names "$fixed_round,$moving_rounds" \
        --registration_moving_acq_names "${moving_rounds}" \
        $@
