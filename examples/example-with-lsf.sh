./main.nf \
        -with-tower 'http://nextflow.int.janelia.org/api' \
        -profile lsf \
        --runtime_opts "--nv -B /nrs/scicompsoft/goinac" \
        --lsf_opts "-P multifish" \
        --workers 4 \
        --worker_cores 4 \
        --driver_memory 15g \
        --spark_work_dir "$PWD/local" \
        --stitching_app "$PWD/external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --data_dir /nrs/scicompsoft/goinac/multifish/ex1 \
        --stitching_output stitching \
        --segmentation_model_dir "$PWD/models/starfinity-model" \
        --reference_acq_name LHA3_R3 \
        --acq_names "LHA3_R3"

