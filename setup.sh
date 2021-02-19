#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)
BASEDIR=$(realpath $DIR/..)

# Download Nextflow Spark module
curl -skL https://github.com/JaneliaSciComp/nextflow-spark/archive/1.1.0.tar.gz | tar -xz --strip-components=1 -C $DIR/external-modules/spark

# Download Starfinity model
segmentation_dir=$BASEDIR/external-modules/segmentation
segmentation_modeldir="$segmentation_dir/model/starfinity"
if [ ! -e $segmentation_modeldir ]; then
    echo "Extracting Starfinity model..."
    mkdir -p segmentation_dir
    $BASEDIR/data-sets/download_dataset.sh "$BASEDIR/data-sets/segmentation.txt" "$segmentation_dir"
    unzip -o $inputdir/model.zip -d $inputdir/    
fi
