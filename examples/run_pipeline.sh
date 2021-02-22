#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
$DIR/../main.nf \
        -dump-channels \
        -with-tower "http://nextflow.int.janelia.org/api" \
        --runtime_opts "--nv -B /nrs/scicompsoft/goinac -B /nrs/multifish" \
        --lsf_opts "-P multifish" \
        --workers "4" \
        --worker_cores "4" \
        --spark_work_dir "$PWD/local" \
        --data_dir "/nrs/multifish/Pipeline/Examples/subset" \
        --output_dir "/nrs/scicompsoft/goinac/multifish/ex1" \
        --acq_names "LHA3_R3_subset,LHA3_R5_subset" \
        --ref_acq "LHA3_R3_subset" \
        --segmentation_model_dir "/nrs/scicompsoft/goinac/multifish/models/starfinity-model" "$@"
        