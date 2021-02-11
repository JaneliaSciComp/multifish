#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)
#$DIR/../main-spots-extraction.nf -profile lsf \
$DIR/../main-spots-extraction.nf -profile localsingularity \
    -with-tower 'http://nextflow.int.janelia.org/api' \
    --lsf_opts "-P multifish"
    --runtime_opts "-B /nrs/scicompsoft/goinac/multifish"  \
    --stitchdir=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3_subset/stitching/export.n5 \
    --outdir=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3_subset/extracted-spots \
    $@
