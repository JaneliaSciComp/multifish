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
    acq_stitching_dir_pairs = prepare_stitching_data(
        input_dir,
        output_dir,
        Channel.fromList(acquisitions),
        stitching_output
    )

    acq_inputs = acq_stitching_dir_pairs
        .map {
            acq_name = it[0]
            acq_stitching_dir = it[1]
            acq_spark_work_dir = "${spark_work_dir}/${acq_name}"
            [ acq_name, acq_stitching_dir, acq_spark_work_dir ]
        }

    done = stitch_acquisition(
        stitching_app,
        acq_inputs.map { it[0] },
        acq_inputs.map { it[1] },
        channels,
        resolution,
        axis_mapping,
        block_size,
        registration_channel,
        stitching_mode,
        stitching_padding,
        blur_sigma,
        spark_conf,
        acq_inputs.map { it[2] },
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
    spark_driver_stack_size = ''
    spark_driver_deploy_mode = ''
    terminate_stitching_name = 'terminate-stitching'

    indexed_acq_names = index_channel(acq_names)
    indexed_stitching_dirs = index_channel(stitching_dirs)
    indexed_spark_work_dirs = index_channel(spark_work_dirs)

    // start a spark cluster
    spark_cluster_res = spark_cluster(
        spark_conf,
        spark_work_dirs,
        spark_workers,
        spark_worker_cores,
        terminate_stitching_name
    )

    indexed_spark_uris = indexed_spark_work_dirs
        .join(spark_cluster_res, by:1)
        .map { [ it[0], it[2] ] }

    // create a channel of tuples:  [index, acq, spark_uri, stitching_dir, spark_work_dir]
    indexed_acq_data = indexed_acq_names
        .join(indexed_spark_uris)
        .join(indexed_stitching_dirs)
        .join(indexed_spark_work_dirs)

    // prepare parse czi tiles
    parse_czi_args = indexed_acq_data | map {
        acq_name = it[1]
        spark_uri = it[2]
        stitching_dir = it[3]
        spark_work_dir = it[4]
        mvl_inputs = entries_inputs_args(stitching_dir, [ acq_name ], '-i', '', '.mvl')
        czi_inputs = entries_inputs_args('', [ acq_name ], '-f', '', '.czi')
        app_args = "${mvl_inputs} \
         ${czi_inputs} \
         -r '${resolution}' \
         -a '${axis_mapping}' \
         -b ${stitching_dir}"
         [ spark_uri, app_args, spark_work_dir ]
    }
    parse_czi_done = run_parse_czi_tiles(
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
    c.reduce([0, []]) { a, b ->
        indexed_elem = [a[0], b]
        a[1].add(indexed_elem)
        [a[0]+1, a[1]]
    } | map { it[1] }
}
