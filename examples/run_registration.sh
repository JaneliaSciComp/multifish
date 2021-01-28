#!/bin/bash

#PROFILE="-profile localsingularity"
#PROFILE='-profile lsf --lsf_opts "-P multifish"'
#-with-tower 'http://nextflow.int.janelia.org/api' \

#./workflows/registration.nf -profile lsf --lsf_opts "-P multifish" \
./workflows/registration.nf -profile localsingularity \
    --runtime_opts "-B /nrs/scicompsoft/goinac/multifish -B /nrs/scicompsoft/rokicki"  \
    --fixed=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3/stitching_kr/export.n5 \
    --moving=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R5/stitching_kr/export.n5 \
    --outdir=/nrs/scicompsoft/rokicki/multifish/LHA_R5_TO_R3_lsf4 $@

