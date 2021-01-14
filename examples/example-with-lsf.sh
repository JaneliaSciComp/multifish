./main.nf \
        -profile lsf \
        --runtime_opts "-B /nrs/scicompsoft/goinac" \
        --lsf_opts "-P scicompsoft" \
        --workers 4 \
        --worker_cores 4 \
        --driver_memory 15g \
        --spark_work_dir "$PWD/local" \
        --stitching_app "external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --data_dir /nrs/scicompsoft/goinac/multifish/ex1 \
        --acq_names "LHA3_R3 LHA3_R5"

