rounds="LHA3_R3_subset,LHA3_R5_subset"
fixed_round="LHA3_R3_subset"
moving_rounds="LHA3_R5_subset"
./main.nf \
        -with-tower 'http://nextflow.int.janelia.org/api' \
        -profile localsingularity \
        --lsf_opts "-P multifish" \
        --runtime_opts "--nv -B /nrs/scicompsoft/goinac -B /nrs/multifish" \
        --workers 4 \
        --worker_cores 4 \
        --driver_memory 15g \
        --spark_work_dir "$PWD/local" \
        --stitching_app "$PWD/external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar" \
        --data_dir /nrs/multifish/Pipeline/Examples/subset \
        --output_dir /nrs/scicompsoft/goinac/multifish/ex1 \
        --segmentation_model_dir "/nrs/scicompsoft/goinac/multifish/models/starfinity-model" \
        --reference_acq_name ${fixed_round} \
        --stitch_acq_names ${rounds} \
        --registration_moving_acq_names ${moving_rounds}
