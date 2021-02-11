#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)
#$DIR/../main-assign-spots.nf -profile lsf --lsf_opts "-P multifish" \
$DIR/../main-assign-spots.nf -profile localsingularity \
    -with-tower 'http://nextflow.int.janelia.org/api' \
    --runtime_opts "-B /nrs/scicompsoft/goinac/multifish"  \
    --labels=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3_subset/segmentation/LHA3_R3_subset-c2.tif \
    --warped_spots=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R5_subset/spots/LHA3_R5_subset-to-LHA3_R3_subset \
    --outdir=/nrs/scicompsoft/goinac/multifish/ex1/LHA_R5_TO_R3_assignment $@
