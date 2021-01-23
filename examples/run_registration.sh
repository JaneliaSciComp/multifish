#!/bin/bash
./workflows/registration.nf -profile localsingularity \
    --runtime_opts "-B /nrs/scicompsoft/goinac/multifish -B /groups/scicompsoft/home/rokickik/multifish"  \
    --fixed=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R3/stitching_kr/export.n5 \
    --moving=/nrs/scicompsoft/goinac/multifish/ex1/LHA3_R5/stitching_kr/export.n5 \
    --outdir=/groups/scicompsoft/home/rokickik/multifish/LHA_R5_TO_R3 $@

