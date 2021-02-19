#!/bin/bash
set -e 

BASEDIR=$(cd "$(dirname "$0")"; pwd)

# Download Nextflow Spark module
curl -skL https://github.com/JaneliaSciComp/nextflow-spark/archive/1.1.0.tar.gz | tar -xz --strip-components=1 -C $BASEDIR/external-modules/spark

# Download Starfinity model
segmentation_dir=$BASEDIR/external-modules/segmentation
segmentation_modeldir="$segmentation_dir/model/starfinity"
if [ ! -e $segmentation_modeldir ]; then
    echo "Extracting Starfinity model..."
    mkdir -p segmentation_dir
    $BASEDIR/data-sets/download_dataset.sh "$BASEDIR/data-sets/segmentation.txt" "$segmentation_dir"
    unzip -o $segmentation_dir/model.zip -d $segmentation_dir/    
fi

echo "Setup complete"
