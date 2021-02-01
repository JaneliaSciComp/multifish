include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_parse_czi_tiles;
    run_spark_app_on_existing_cluster as run_czi2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
    run_spark_app_on_existing_cluster as run_retile;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_stitching_export;
} from '../external-modules/spark/lib/workflows' addParams(lsf_opts: params.lsf_opts, 
                                                           crepo: params.crepo,
                                                           spark_version: params.spark_version)

include {
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/processes' addParams(lsf_opts: params.lsf_opts, 
                                                           crepo: params.crepo,
                                                           spark_version: params.spark_version)

include {
    prepare_stitching_data;
} from '../processes/stitching'

include {
    entries_inputs_args
} from './stitching_utils'

workflow stitch_multiple_acquisitions {
    take:
    stitching_app
    acquisitions
    input_dir
    output_dir
    stitching_output
    channels
    resolution
    axis_mapping
    block_size
    registration_channel
    stitching_mode
    stitching_padding
    blur_sigma
    spark_conf
    spark_work_dir
    spark_workers
    spark_worker_cores
    spark_gbmem_per_core
    spark_driver_cores
    spark_driver_memory
    spark_driver_logconfig

    main:
    def acq_stitching_dir_pairs = prepare_stitching_data(
        input_dir,
        output_dir,
        Channel.fromList(acquisitions),
        stitching_output
    )

    def acq_inputs = acq_stitching_dir_pairs
        .map {
            acq_name = it[0]
            acq_stitching_dir = it[1]
            acq_spark_work_dir = "${spark_work_dir}/${acq_name}"
            acq_input = [ acq_name, acq_stitching_dir, acq_spark_work_dir ]
            println "Create acq input ${acq_input} from ${it} and ${spark_work_dir}"
            return acq_input
        }
        .multiMap { it ->
            println "Put acq name '${it[0]}' into acq_names channel"
            println "Put stitching dir '${it[1]}' into stitching_dirs channel"
            println "Put spark work dir '${it[2]}' into spark_work_dirs channel"
            acq_names: it[0]
            stitching_dirs: it[1]
            spark_work_dirs: it[2]
        }

    done = stitch_acquisition(
        stitching_app,
        acq_inputs.acq_names,
        acq_inputs.stitching_dirs,
        channels,
        resolution,
        axis_mapping,
        block_size,
        registration_channel,
        stitching_mode,
        stitching_padding,
        blur_sigma,
        spark_conf,
        acq_inputs.spark_work_dirs,
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_logconfig
    )

    emit:
    done
}

/**
 * run stitching for a single acquisition
 */
workflow stitch_acquisition {
    take:
    stitching_app
    acq_names
    stitching_dirs
    channels
    resolution
    axis_mapping
    block_size
    registration_channel
    stitching_mode
    stitching_padding
    blur_sigma
    spark_conf
    spark_work_dirs
    spark_workers
    spark_worker_cores
    spark_gbmem_per_core
    spark_driver_cores
    spark_driver_memory
    spark_driver_logconfig

    main:
    def spark_driver_stack_size = ''
    def spark_driver_deploy_mode = ''
    def terminate_stitching_name = 'terminate-stitching'

    def indexed_acq_names = index_channel(acq_names)
    def indexed_stitching_dirs = index_channel(stitching_dirs)
    def indexed_spark_work_dirs = index_channel(spark_work_dirs)

    indexed_acq_names.subscribe { println "Indexed acq: $it" }
    indexed_stitching_dirs.subscribe { println "Indexed stitching dir: $it" }
    indexed_spark_work_dirs.subscribe { println "Indexed spark working dir: $it" }

    // start a spark cluster
    def spark_cluster_res = spark_cluster(
        spark_conf,
        spark_work_dirs,
        spark_workers,
        spark_worker_cores,
        terminate_stitching_name
    )

    spark_cluster_res.subscribe {  println "Spark cluster result: $it"  }

    def indexed_spark_uris = spark_cluster_res
        .join(indexed_spark_work_dirs, by:1)
        .map {
            println "Create indexed spark URI from: $it"
            [ it[2], it[1] ]
        }

    indexed_spark_uris.subscribe { println "Spark URI: $it" }

    // create a channel of tuples:  [index, spark_uri, acq, stitching_dir, spark_work_dir]
    def indexed_acq_data = indexed_acq_names \
        | join(indexed_spark_uris)
        | join(indexed_stitching_dirs)
        | join(indexed_spark_work_dirs)

    // prepare parse czi tiles
    def parse_czi_args = indexed_acq_data | map {
        println "Create parse czi app inputs  from ${it}"
        def idx = it[0]
        def acq_name = it[1]
        def spark_uri = it[2]
        def stitching_dir = it[3]
        def spark_work_dir = it[4]
        def mvl_inputs = entries_inputs_args(stitching_dir, [ acq_name ], '-i', '', '.mvl')
        def czi_inputs = entries_inputs_args('', [ acq_name ], '-f', '', '.czi')
        def app_args = "${mvl_inputs} \
         ${czi_inputs} \
         -r '${resolution}' \
         -a '${axis_mapping}' \
         -b ${stitching_dir}"
         def parse_czi_app_inputs = [ spark_uri, app_args, spark_work_dir ]
         println "Parse czi app input ${idx}: ${parse_czi_app_inputs}"
         return parse_czi_app_inputs
    }
    def parse_czi_done = run_parse_czi_tiles(
        parse_czi_args.map { it[0] },
        stitching_app,
        'org.janelia.stitching.ParseCZITilesMetadata',
        parse_czi_args.map { it[1] },
        'parseCZITiles.log',
        terminate_stitching_name,
        spark_conf,
        parse_czi_args.map { it[2] },
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack_size,
        spark_driver_logconfig,
        spark_driver_deploy_mode
    )
    // // prepare czi to n5
    // czi_to_n5_args = parse_czi_done | map { 
    //     tiles_json = entries_inputs_args(stitching_dir, ['tiles'], '-i', '', '.json')
    //     "${tiles_json} --blockSize '${block_size}'"
    // }
    // czi_to_n5_done = run_czi2n5(
    //     spark_uri,
    //     stitching_app,
    //     'org.janelia.stitching.ConvertCZITilesToN5Spark',
    //     czi_to_n5_args,
    //     'czi2n5.log',
    //     terminate_stitching_name,
    //     spark_conf,
    //     spark_work_dir,
    //     spark_workers,
    //     spark_worker_cores,
    //     spark_gbmem_per_core,
    //     spark_driver_cores,
    //     spark_driver_memory,
    //     spark_driver_stack_size,
    //     spark_driver_logconfig,
    //     spark_driver_deploy_mode
    // )
    // // prepare flatfield args
    // flatfield_args = czi_to_n5_done | map {
    //     n5_channels_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5', '.json')
    //     "${n5_channels_args} --2d --bins 256"
    // }
    // flatfield_done = run_flatfield_correction(
    //     spark_uri,
    //     stitching_app,
    //     'org.janelia.flatfield.FlatfieldCorrection',
    //     flatfield_args,
    //     'flatfieldCorrection.log',
    //     terminate_stitching_name,
    //     spark_conf,
    //     spark_work_dir,
    //     spark_workers,
    //     spark_worker_cores,
    //     spark_gbmem_per_core,
    //     spark_driver_cores,
    //     spark_driver_memory,
    //     spark_driver_stack_size,
    //     spark_driver_logconfig,
    //     spark_driver_deploy_mode
    // )
    // // prepare retile args
    // retile_args = flatfield_done | map {
    //     entries_inputs_args(stitching_dir, channels, '-i', '-n5', '.json')
    // }
    // retile_done = run_retile(
    //     spark_uri,
    //     stitching_app,
    //     'org.janelia.stitching.ResaveAsSmallerTilesSpark',
    //     retile_args,
    //     'retileImages.log',
    //     terminate_stitching_name,
    //     spark_conf,
    //     spark_work_dir,
    //     spark_workers,
    //     spark_worker_cores,
    //     spark_gbmem_per_core,
    //     spark_driver_cores,
    //     spark_driver_memory,
    //     spark_driver_stack_size,
    //     spark_driver_logconfig,
    //     spark_driver_deploy_mode
    // )
    // // prepare stitching args
    // stitching_args = retile_done | map {
    //     retiled_n5_channels_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5-retiled', '.json')
    //     "--stitch -r ${registration_channel} ${retiled_n5_channels_args} --mode '${stitching_mode}' --padding '${stitching_padding}' --blurSigma ${blur_sigma}"
    // }
    // stitching_done = run_stitching(
    //     spark_uri,
    //     stitching_app,
    //     'org.janelia.stitching.StitchingSpark',
    //     stitching_args,
    //     'stitching.log',
    //     terminate_stitching_name,
    //     spark_conf,
    //     spark_work_dir,
    //     spark_workers,
    //     spark_worker_cores,
    //     spark_gbmem_per_core,
    //     spark_driver_cores,
    //     spark_driver_memory,
    //     spark_driver_stack_size,
    //     spark_driver_logconfig,
    //     spark_driver_deploy_mode
    // )
    // // prepare fuse args
    // fuse_args = stitching_done | map {
    //     stitched_n5_channels_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5-retiled-final', '.json')
    //     "--fuse ${stitched_n5_channels_args} --blending --fill"
    // }
    // fuse_done = run_stitching_export(
    //     spark_uri,
    //     stitching_app,
    //     'org.janelia.stitching.StitchingSpark',
    //     fuse_args,
    //     'export2n5.log',
    //     terminate_stitching_name,
    //     spark_conf,
    //     spark_work_dir,
    //     spark_workers,
    //     spark_worker_cores,
    //     spark_gbmem_per_core,
    //     spark_driver_cores,
    //     spark_driver_memory,
    //     spark_driver_stack_size,
    //     spark_driver_logconfig,
    //     spark_driver_deploy_mode
    // )
    // terminate stitching cluster
    done = terminate_stitching(parse_czi_done, terminate_stitching_name) | map { stitching_dir }

    emit:
    done
}

def index_channel(c) {
    c.reduce([ 0, [] ]) { accum, elem ->
        def indexed_elem = [accum[0], elem]
        [ accum[0]+1, accum[1]+[indexed_elem] ]
    } | map { it[1] }
}
