#!/bin/bash

profile=
other_args=()

while [[ $# > 0 ]]; do
    key="$1"
    shift # past the key
    case $key in
        -p|--profile)
            profile="$1"
            shift
            ;;
        *)
            other_args=("${other_args[@]}" ${key})
            ;;
    esac
done

if [[ "$profile" == "lsf" ]] ; then
    profile=lsf
else
    profile=localsingularity
fi

DIR=$(cd "$(dirname "$0")"; pwd)

$DIR/../main.nf \
        -dump-channels \
        -with-tower 'http://nextflow.int.janelia.org/api' \
        -profile $profile \
        --runtime_opts "--nv -B /nrs/scicompsoft/goinac -B /nrs/multifish" \
        --lsf_opts "-P multifish" \
        --workers 4 \
        --worker_cores 4 \
        --spark_work_dir "$PWD/local" \
        --stitching_app "$PWD/external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --data_dir /nrs/multifish/Pipeline/Examples/subset \
        --output_dir /nrs/scicompsoft/goinac/multifish/ex1 \
        --acq_names "LHA3_R3_subset,LHA3_R5_subset" \
        --ref_acq "LHA3_R3_subset" \
        --segmentation_model_dir "/nrs/scicompsoft/goinac/multifish/models/starfinity-model"
