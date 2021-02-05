#!/bin/bash

#./workflows/registration.nf -profile localsingularity \
./workflows/registration.nf -profile lsf --lsf_opts "-P multifish" \
    -with-tower 'http://nextflow.int.janelia.org/api' \
    --runtime_opts "-B /nrs/scicompsoft/goinac/multifish -B /nrs/scicompsoft/rokicki"  \
    --fixed=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3_subset/stitching/export.n5 \
    --moving=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R5_subset/stitching/export.n5 \
    --reg_outdir=/nrs/scicompsoft/rokicki/multifish/LHA_R5_TO_R3_subset $@

