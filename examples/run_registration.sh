#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)
#$DIR/../main-registration.nf -profile lsf --lsf_opts "-P multifish" \
    #-with-tower 'http://nextflow.int.janelia.org/api' \
$DIR/../main-registration.nf -profile localsingularity \
    --runtime_opts "-B /nrs/scicompsoft/goinac/multifish -B /nrs/scicompsoft/rokicki"  \
    --fixed=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3_subset/stitching/export.n5 \
    --moving=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R5_subset/stitching/export.n5 \
    --outdir=/nrs/scicompsoft/rokicki/multifish/LHA_R5_TO_R3_subset2 $@

