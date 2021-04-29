#!/bin/bash

DIR=$(cd "$(dirname "$0")"; pwd)

nextflow run $DIR/../main.nf \
    -profile awsbatch \
    -e.SPARK_LOCAL_DIR=/scratch/multifish/spark \
    -w s3://janelia-nextflow-demo/multifish/work \
    --spark_container_repo "job-definition://easi-multifish-dev-spark-job-definition" \
    --workers 1 \
    --worker_cores 16 \
    --gb_per_core 1 \
    --spark_work_dir "/scratch/multifish/work" \
    --data_dir "/scratch/multifish/small" \
    --output_dir "/scratch/multifish/results/small" \
    --acq_names "LHA3_R3_small,LHA3_R5_small" \
    --ref_acq "LHA3_R3_small" \
    --segmentation_model_dir "/scratch/multifish/models/starfinity-model"
