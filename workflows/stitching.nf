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
    stitching_inputs


    main:
    // start a spark cluster

    stitching_inputs \
    | map {
        spark_conf = it[6]
        spark_work_dir = it[7]
        nworkers = it[8]
        worker_cores = it[9]
        [
            spark_conf,
            spark_work_dir,
            nworkers,
            worker_cores
        ]
    } \
    | spark_cluster \
    | combine(stitching_inputs) \
    | map {
        println "Prepare parse czi tiles inputs from ${it}"
        spark_uri = it[0]
        stitching_app = it[1]
        data_dir = it[2]
        acq_name = it[3]
        resolution = it[4]
        axis_mapping = it[5]
        block_size = it[6]
        spark_conf = it[7]
        spark_work_dir = it[8]
        nworkers = it[9]
        worker_cores = it[10]
        memgb_per_core = it[11]
        driver_cores = it[12]
        driver_memory = it[13]
        driver_logconfig = it[14]

        mvl_inputs = entries_inputs_args(data_dir, [acq_name], '-i', '', '.mvl')
        czi_inputs = entries_inputs_args('', [acq_name], '-f', '', '.czi')

        [
            spark_uri,
            stitching_app,
            'org.janelia.stitching.ParseCZITilesMetadata',
            "${mvl_inputs} ${czi_inputs} \
            -r '${resolution}' \
            -a '${axis_mapping}' \
            -b ${data_dir}",
            'parseCZITiles.log',
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
        ]
    } \
    | run_parse_czi_tiles \
    | map {
        // get the spark_uri only
        it[0] 
    } \
    | combine(stitching_inputs) \
    | map {
        println "Prepare parse czi to n5 inputs from ${it}"
        spark_uri = it[0]
        stitching_app = it[1]
        data_dir = it[2]
        acq_name = it[3]
        resolution = it[4]
        axis_mapping = it[5]
        block_size = it[6]
        spark_conf = it[7]
        spark_work_dir = it[8]
        nworkers = it[9]
        worker_cores = it[10]
        memgb_per_core = it[11]
        driver_cores = it[12]
        driver_memory = it[13]
        driver_logconfig = it[14]

        tiles_json = entries_inputs_args(data_dir, ['tiles'], '-i', '', '.json')
        [
            spark_uri,
            stitching_app,
            'org.janelia.stitching.ConvertCZITilesToN5Spark',
            "${tile_json_inputs} --blockSize '${block_size}'",
            'czi2n5.log',
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
        ]
    } \
    | run_tiff2n5 \
    | map {
        // get the working dir only
        it[1]
    } \
    | terminate_stitching \
    | set { done }

    emit:
    done
}
