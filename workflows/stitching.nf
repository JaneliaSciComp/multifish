include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_parse_czi_tiles;
    run_spark_app_on_existing_cluster as run_czi2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
    run_spark_app_on_existing_cluster as run_retile;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_fuse;
} from '../external-modules/spark/lib/workflows'

include {
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/processes'

include {
    prepare_stitching_data;
} from '../processes/stitching'

include {
    entries_inputs_args;
} from './stitching_utils'

include {
    index_channel;
} from './utils'

/**
 * prepares the work and output directories and invoke stitching 
 * for the aquisitions list - this is a value channel containing a list of acquistins
 *
 * @return tuple of <acq_name, acq_stitching_dir>
 */
workflow stitching {
    take:
    stitching_app
    acquisitions
    input_dir
    output_dir
    stitching_output
    channels
    resolution
    axis_mapping
    stitching_block_size
    retile_z_size
    registration_channel
    stitching_mode
    stitching_padding
    stitching_blur_sigma
    stitching_czi_pattern
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
            log.debug "Create acq input ${acq_input} from ${it} and ${spark_work_dir}"
            return acq_input
        }
        .multiMap { it ->
            log.debug "Put acq name '${it[0]}' into acq_names channel"
            log.debug "Put stitching dir '${it[1]}' into stitching_dirs channel"
            log.debug "Put spark work dir '${it[2]}' into spark_work_dirs channel"
            acq_names: it[0]
            stitching_dirs: it[1]
            spark_work_dirs: it[2]
        }

    def stitching_results = stitch(
        stitching_app,
        acq_inputs.acq_names,
        acq_inputs.stitching_dirs,
        channels,
        resolution,
        axis_mapping,
        stitching_block_size,
        retile_z_size,
        registration_channel,
        stitching_mode,
        stitching_padding,
        stitching_blur_sigma,
        stitching_czi_pattern,
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
    done = stitching_results
}

/**
 * run stitching for the given acquisitions.
 *
 * @return tuple of <acq_name, acq_stitching_dir>
 */
workflow stitch {
    take:
    stitching_app
    acq_names
    stitching_dirs
    channels
    resolution
    axis_mapping
    stitching_block_size
    retile_z_size
    registration_channel
    stitching_mode
    stitching_padding
    stitching_blur_sigma
    stitching_czi_pattern
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

    // index inputs so that I can pair acq name with the corresponding spark URI and/or spark working dir
    def indexed_acq_names = index_channel(acq_names)
    def indexed_stitching_dirs = index_channel(stitching_dirs)
    def indexed_spark_work_dirs = index_channel(spark_work_dirs)

    indexed_acq_names.subscribe { log.debug "Indexed acq: $it" }
    indexed_stitching_dirs.subscribe { log.debug "Indexed stitching dir: $it" }
    indexed_spark_work_dirs.subscribe { log.debug "Indexed spark working dir: $it" }

    // start a spark cluster
    def spark_cluster_res = spark_cluster(
        spark_conf,
        spark_work_dirs,
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        terminate_stitching_name
    )
    // print spark cluster result
    spark_cluster_res.subscribe {  log.debug "Spark cluster result: $it"  }

    def indexed_spark_uris = spark_cluster_res
        .join(indexed_spark_work_dirs, by:1)
        .map {
            def indexed_uri = [ it[2], it[1] ]
            log.debug "Create indexed spark URI from $it -> ${indexed_uri}"
            return indexed_uri
        }

    // create a channel of tuples:  [index, spark_uri, acq, stitching_dir, spark_work_dir]
    def indexed_acq_data = indexed_acq_names
        | join(indexed_spark_uris)
        | join(indexed_stitching_dirs)
        | join(indexed_spark_work_dirs)

    // prepare parse czi tiles
    def parse_czi_args = prepare_app_args(
        "parseCZI",
        indexed_spark_work_dirs, //  here I only want a tuple that has the working dir as the 2nd element
        indexed_spark_work_dirs,
        indexed_acq_data,
        { acq_name, stitching_dir ->
            def mvl_inputs = entries_inputs_args(stitching_dir, [ acq_name ], '-i', '', '.mvl')
            def czi_inputs = entries_inputs_args('', [ acq_name ], '-f', stitching_czi_pattern, '.czi')
            return "${mvl_inputs} ${czi_inputs} -r '${resolution}' -a '${axis_mapping}' -b ${stitching_dir}"
        }
    )
    def parse_czi_done = run_parse_czi_tiles(
        parse_czi_args.map { it[0] }, // spark URI
        stitching_app,
        'org.janelia.stitching.ParseCZITilesMetadata',
        parse_czi_args.map { it[1] }, // app args
        'parseCZITiles.log',
        terminate_stitching_name,
        spark_conf,
        parse_czi_args.map { it[2] }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack_size,
        spark_driver_logconfig,
        spark_driver_deploy_mode
    )
    // prepare czi to n5
    def czi_to_n5_args = prepare_app_args(
        "czi2N5",
        parse_czi_done,
        indexed_spark_work_dirs,
        indexed_acq_data,
        { acq_name, stitching_dir ->
            def tiles_json = entries_inputs_args(stitching_dir, [ 'tiles' ], '-i', '', '.json')
            return "${tiles_json} --blockSize '${stitching_block_size}'"
        }
    )
    def czi_to_n5_done = run_czi2n5(
        czi_to_n5_args.map { it[0] }, // spark URI
        stitching_app,
        'org.janelia.stitching.ConvertCZITilesToN5Spark',
        czi_to_n5_args.map { it[1] }, // app args
        'czi2n5.log',
        terminate_stitching_name,
        spark_conf,
        czi_to_n5_args.map { it[2] }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack_size,
        spark_driver_logconfig,
        spark_driver_deploy_mode
    )
    def flatfield_done = czi_to_n5_done;
    if (params.flatfield_correction) {
        // prepare flatfield args
        def flatfield_args = prepare_app_args(
            "flatfield",
            czi_to_n5_done,
            indexed_spark_work_dirs,
            indexed_acq_data,
            { acq_name, stitching_dir ->
                def n5_channels_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5', '.json')
                return "${n5_channels_args} --2d --bins 256"
            }
        )
        flatfield_done = run_flatfield_correction(
            flatfield_args.map { it[0] }, // spark URI
            stitching_app,
            'org.janelia.flatfield.FlatfieldCorrection',
            flatfield_args.map { it[1] }, // app args
            'flatfieldCorrection.log',
            terminate_stitching_name,
            spark_conf,
            flatfield_args.map { it[2] }, // spark working dir
            spark_workers,
            spark_worker_cores,
            spark_gbmem_per_core,
            spark_driver_cores,
            spark_driver_memory,
            spark_driver_stack_size,
            spark_driver_logconfig,
            spark_driver_deploy_mode
        )
    }
    // prepare retile args
    def retile_args = prepare_app_args(
        "retile",
        flatfield_done,
        indexed_spark_work_dirs,
        indexed_acq_data,
        { acq_name, stitching_dir ->
            def retile_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5', '.json')
            return "${retile_args} --size ${retile_z_size}"
        }
    )
    def retile_done = run_retile(
        retile_args.map { it[0] }, // spark URI
        stitching_app,
        'org.janelia.stitching.ResaveAsSmallerTilesSpark',
        retile_args.map { it[1] }, // app args
        'retileImages.log',
        terminate_stitching_name,
        spark_conf,
        retile_args.map { it[2] }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack_size,
        spark_driver_logconfig,
        spark_driver_deploy_mode
    )
    // prepare stitching args
    def stitching_args = prepare_app_args(
        "stitching",
        retile_done,
        indexed_spark_work_dirs,
        indexed_acq_data,
        { acq_name, stitching_dir ->
            def retiled_n5_channels_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5-retiled', '.json')
            def correction_args = entries_inputs_args(stitching_dir, channels, '--correction-images-paths', '-n5', '.json')
            def ref_channel_arg = registration_channel ? "-r ${registration_channel}" : ''
            return "--stitch ${ref_channel_arg} ${retiled_n5_channels_args} ${correction_args} --mode '${stitching_mode}' --padding '${stitching_padding}' --blurSigma ${stitching_blur_sigma}"
        }
    )
    def stitching_done = run_stitching(
        stitching_args.map { it[0] }, // spark URI
        stitching_app,
        'org.janelia.stitching.StitchingSpark',
        stitching_args.map { it[1] }, // app args
        'stitching.log',
        terminate_stitching_name,
        spark_conf,
        stitching_args.map { it[2] }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack_size,
        spark_driver_logconfig,
        spark_driver_deploy_mode
    )
    // prepare fuse args
    def fuse_args = prepare_app_args(
        "fuse",
        stitching_done,
        indexed_spark_work_dirs,
        indexed_acq_data,
        { acq_name, stitching_dir ->
            def stitched_n5_channels_args = entries_inputs_args(stitching_dir, channels, '-i', '-n5-retiled-final', '.json')
            def correction_args = entries_inputs_args(stitching_dir, channels, '--correction-images-paths', '-n5', '.json')
            return "--fuse ${stitched_n5_channels_args} ${correction_args} --blending --fill"
        }
    )
    def fuse_done = run_fuse(
        fuse_args.map { it[0] }, // spark URI
        stitching_app,
        'org.janelia.stitching.StitchingSpark',
        fuse_args.map { it[1] }, // app args
        'fuse.log',
        terminate_stitching_name,
        spark_conf,
        fuse_args.map { it[2] }, // spark working dir
        spark_workers,
        spark_worker_cores,
        spark_gbmem_per_core,
        spark_driver_cores,
        spark_driver_memory,
        spark_driver_stack_size,
        spark_driver_logconfig,
        spark_driver_deploy_mode
    )
    // terminate stitching cluster
    done = terminate_stitching(
        fuse_done.map { it[1] },
        terminate_stitching_name
    ) | join(indexed_spark_work_dirs, by:1) | map { 
        [ it[2], it[0] ]
    } | join(indexed_acq_data) | map {
        log.debug "Completed stitching for ${it}"
        // acq_name, acq_stitching_dir
        [ it[2], it[4] ]
    }

    emit:
    done
}

def prepare_app_args(app_name,
                     previous_result_dirs,
                     indexed_working_dirs,
                     indexed_acq_data,
                     app_args_closure) {
    return previous_result_dirs | join(indexed_working_dirs, by: 1) | map {
        // reverse the order in the tuple because the join key is the working dir
        def r = [ it[2], it[0] ]
        log.debug "Indexed result from: $it -> $r"
        return r
    } | join(indexed_acq_data) | map {
        log.debug "Create ${app_name} inputs from ${it}"
        def idx = it[0]
        def acq_name = it[2]
        def spark_uri = it[3]
        def stitching_dir = it[4]
        def spark_work_dir = it[1] // spark work dir comes from previous result
        log.debug "Get ${app_name} args using: (${acq_name}, ${stitching_dir})"
        def app_args = app_args_closure.call(acq_name, stitching_dir)
        def app_inputs = [ spark_uri, app_args, spark_work_dir ]
        log.debug "${app_name} app input ${idx}: ${app_inputs}"
        return app_inputs
    }
}
