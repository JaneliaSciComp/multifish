include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_parse_czi_tiles;
    run_spark_app_on_existing_cluster as run_tiff2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_final_stitching;
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/spark' addParams(lsf_opts: params.lsf_opts, 
                                                       crepo: params.crepo,
                                                       spark_version: params.spark_version)

include {
    entries_inputs_args
} from './stitching_utils'

workflow stitching {
    take:
    stitching_app
    data_dir
    data_entries
    resolution
    axis_mapping
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
    // start a spark cluster
    spark_uri = spark_cluster(spark_conf, spark_work_dir, nworkers, worker_cores)

    // parse tiles
    mvl_inputs = entries_inputs_args(data_dir, data_entries, '-i', '', '.mvl')
    czi_inputs = entries_inputs_args('', data_entries, '-f', '', '.czi')

    parse_res = run_parse_czi_tiles(
        spark_uri,
        stitching_app,
        "org.janelia.stitching.ParseCZITilesMetadata",
        "${mvl_inputs} ${czi_inputs} \
         -r '${resolution}' \
         -a '${axis_mapping}' \
         -b ${data_dir}",
        "parseCZITiles.log",
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

    tile_json_inputs = entries_inputs_args(data_dir, ['tiles'], '-i', '', '.json')
    czi2n5_res = run_tiff2n5(
        parse_res,
        stitching_app,
        "org.janelia.stitching.ConvertCZITilesToN5Spark",
        "${tile_json_inputs} --blockSize '${block_size}'",
        "czi2n5.log",
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

    czi2n5_res \
    | map { spark_work_dir } \
    | terminate_stitching \
    | map { data_dir }
    | set { done }

    emit:
    done
}
