include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_parse_tiles;
    run_spark_app_on_existing_cluster as run_tiff2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_final_stitching;
    terminate_spark as terminate_pre_stitching;
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/spark' addParams(lsf_opts: params.lsf_opts, 
                                                       crepo: params.crepo,
                                                       spark_version: params.spark_version)

include {
    channels_json_inputs
} from './stitching_utils'

workflow pre_stitching {
    take:
    stitching_app
    data_dir
    resolution
    axis_mapping
    channels
    block_size
    spark_conf
    spark_work_dir
    nworkers
    worker_cores
    memgb_per_core
    driver_cores
    driver_memory
    driver_logconfig

    main:
    spark_uri = spark_cluster(spark_conf, spark_work_dir, nworkers, worker_cores)
    parse_res = run_parse_tiles(
        spark_uri,
        stitching_app,
        "org.janelia.stitching.ParseTilesImageList",
        "-i ${data_dir}/ImageList_images.csv \
         -r '${resolution}' \
         -a '${axis_mapping}' \
         -b ${data_dir} \
         --skipMissingTiles",
        "parseTiles.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '128m',
        driver_logconfig,
        ''
    )

    tile_json_inputs = channels_json_inputs(data_dir, channels, '')
    tiff2n5_res = run_tiff2n5(
        parse_res,
        stitching_app,
        "org.janelia.stitching.ConvertTIFFTilesToN5Spark",
        "${tile_json_inputs} --blockSize '${block_size}'",
        "tiff2n5.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    n5_json_input = channels_json_inputs(data_dir, channels, '-n5')
    flatfield_res = run_flatfield_correction(
        tiff2n5_res,
        stitching_app,
        "org.janelia.flatfield.FlatfieldCorrection",
        "${n5_json_input} -v 101 --2d --bins 256",
        "flatfield.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    flatfield_res \
    | map { spark_work_dir } \
    | terminate_pre_stitching \
    | map { data_dir }
    | set { done }

    emit:
    done
}

workflow stitching {
    take:
    stitching_app
    data_dir
    channels
    export_level
    spark_conf
    spark_work_dir
    nworkers
    worker_cores
    memgb_per_core
    driver_cores
    driver_memory
    driver_logconfig

    main:
    spark_uri = spark_cluster(spark_conf, spark_work_dir, nworkers, worker_cores)
    stitching_json_inputs = channels_json_inputs(data_dir, channels, '-decon')
    stitching_res = run_stitching(
        spark_uri,
        stitching_app,
        "org.janelia.stitching.StitchingSpark",
        "--stitch \
        -r -1 \
        ${stitching_json_inputs} \
        --mode 'incremental' \
        --padding '0,0,0' --blurSigma 2",
        "stitching.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    final_stitching_json_inputs = channels_json_inputs(data_dir, channels, '-decon-final')
    final_stitching_res = run_final_stitching(
        stitching_res,
        stitching_app,
        "org.janelia.stitching.StitchingSpark",
        "--fuse ${final_stitching_json_inputs} --blending",
        "stitching-final.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    export_res = run_final_stitching(
        final_stitching_res,
        stitching_app,
        "org.janelia.stitching.N5ToSliceTiffSpark",
        "-i ${data_dir}/export.n5 --scaleLevel ${export_level}",
        "export.log",
        spark_conf,
        spark_work_dir,
        nworkers,
        worker_cores,
        memgb_per_core,
        driver_cores,
        driver_memory,
        '',
        driver_logconfig,
        ''
    )

    export_res \
    | map { spark_work_dir } \
    | terminate_stitching \
    | map { data_dir }
    | set { done }

    emit:
    done

}