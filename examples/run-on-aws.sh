#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)

nextflow run $DIR/../main.nf \
    -profile awsbatch \
    -w s3://janelia-nextflow-demo/multifish/work \
    --workers 1 \
    --worker_cores 16 \
    --wait_for_spark_timeout_seconds 3600 \
    --sleep_between_timeout_checks_seconds 2 \
    --gb_per_core 4 \
    --channels "c0,c1" \
    --stitching_ref 1 \
    --dapi_channel c1 \
    --segmentation_cpus 1 \
    --airlocalize_xy_stride 512 \
    --airlocalize_z_stride 256 \
    --airlocalize_cpus 2 \
    --airlocalize_memory "8 G" \
    --spark_local_dir "/tmp" \
    --spark_work_dir "/efs-multifish/spark/small" \
    --data_dir "/s3-multifish/small" \
    --output_dir "/efs-multifish/results/small" \
    --acq_names "LHA3_R3_small,LHA3_R5_small" \
    --ref_acq "LHA3_R3_small" \
    --segmentation_model_dir "/s3-multifish/models/starfinity-model"
