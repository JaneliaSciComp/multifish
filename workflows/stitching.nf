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
    entries_inputs_args
} from './stitching_utils'

workflow stitching {
    take:
    stitching_inputs

    main:
    // start a spark cluster

    stitching_inputs \
    | spark_cluster \
    | combine(stitching_inputs) \
    | map {
        it[1] + [spark_uri: it[0]]
    } \
    | map {
        println "Prepare parse czi tiles inputs for ${it}"
        mvl_inputs = entries_inputs_args(it.stitching_output_dir, [ it.acq_name ], '-i', '', '.mvl')
        czi_inputs = entries_inputs_args('', [ it.acq_name ], '-f', '', '.czi')
        parse_czi_args = "${mvl_inputs} ${czi_inputs} \
                          -r '${it.resolution}' \
                          -a '${it.axis_mapping}' \
                          -b ${it.stitching_output_dir}"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.ParseCZITilesMetadata',
            spark_app_args: parse_czi_args,
            spark_app_log: 'parseCZITiles.log'
        ]
    } \
    | run_parse_czi_tiles \
    | map {
        println "Prepare czi to n5 inputs for ${it}"

        tiles_json = entries_inputs_args(it.stitching_output_dir, ['tiles'], '-i', '', '.json')
        czi_to_n5_args = "${tiles_json} --blockSize '${it.block_size}'"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.ConvertCZITilesToN5Spark',
            spark_app_args: czi_to_n5_args,
            spark_app_log: 'czi2n5.log'
        ]
    } \
    | run_czi2n5 \
    | map {
        println "Prepare flatfield correction inputs for ${it}"

        n5_channels_args = entries_inputs_args(it.stitching_output_dir, it.channels, '-i', '-n5', '.json')
        flatfield_args = "${n5_channels_args} --2d --bins 256"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.flatfield.FlatfieldCorrection',
            spark_app_args: flatfield_args,
            spark_app_log: 'flatfieldCorrection.log'
        ]
    } \
    | run_flatfield_correction \
    | map {
        println "Prepare retiling inputs for ${it}"

        retile_args = entries_inputs_args(it.stitching_output_dir, it.channels, '-i', '-n5', '.json')
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.ResaveAsSmallerTilesSpark',
            spark_app_args: retile_args,
            spark_app_log: 'retileImages.log'
        ]
    } \
    | run_retile \
    | map {
        println "Prepare stitching inputs for ${it}"

        retiled_n5_channels_args = entries_inputs_args(it.stitching_output_dir, it.channels, '-i', '-n5-retiled', '.json')
        stitching_args = "--stitch -r ${it.registration_channel} ${retiled_n5_channels_args} --mode '${it.stitching_mode}' --padding '${it.stitching_padding}' --blurSigma ${it.blur_sigma}"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.StitchingSpark',
            spark_app_args: stitching_args,
            spark_app_log: 'stitching.log'
        ]
    } \
    | run_stitching \
    | map {
        println "Prepare stitching export to n5 inputs for ${it}"

        stitched_n5_channels_args = entries_inputs_args(it.stitching_output_dir, it.channels, '-i', '-n5-retiled-final', '.json')
        export_args = "--fuse ${stitched_n5_channels_args} --blending --fill"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.StitchingSpark',
            spark_app_args: export_args,
            spark_app_log: 'export2n5.log'
        ]
    } \
    | run_stitching_export \
    | map {
        [
            it.spark_work_dir,
            it.spark_app_terminate_name
        ]
    } \
    | terminate_stitching \
    | set { done }

    emit:
    done
}
