include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_parse_czi_tiles;
    run_spark_app_on_existing_cluster as run_czi2n5;
    run_spark_app_on_existing_cluster as run_flatfield_correction;
    run_spark_app_on_existing_cluster as run_stitching;
    run_spark_app_on_existing_cluster as run_final_stitching;
    terminate_spark as terminate_stitching;
} from '../external-modules/spark/lib/workflows' addParams(lsf_opts: params.lsf_opts, 
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
        stitching_output = it.stitching_output == null || it.stitching_output == ''
            ? it.data_dir
            : it.stitching_output
        stitching_output_dir = file(stitching_output, it.acq_name)
        stitching_output_dir.mkdirs()
        it + [stitching_output_dir: stitching_output_dir]
    } \
    | spark_cluster \
    | combine(stitching_inputs) \
    | map {
        it[1] + [spark_uri: it[0]]
    } \
    | map {
        println "Prepare parse czi tiles inputs from ${it}"
        mvl_inputs = entries_inputs_args(it.data_dir, [ it.acq_name ], '-i', '', '.mvl')
        czi_inputs = entries_inputs_args('', [ it.acq_name ], '-f', '', '.czi')
        parse_czi_args = "${mvl_inputs} ${czi_inputs} \
                          -r '${it.resolution}' \
                          -a '${it.axis_mapping}' \
                          -b ${it.data_dir}"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.ParseCZITilesMetadata',
            spark_app_args: parse_czi_args,
            spark_app_log: 'parseCZITiles.log'
        ]
    } \
    | run_parse_czi_tiles \
    | map {
        println "Prepare parse czi to n5 inputs from ${it}"

        tiles_json = entries_inputs_args(it.data_dir, ['tiles'], '-i', '', '.json')
        czi_to_n5_args = "${tiles_json} --blockSize '${block_size}'"
        it + [
            spark_app: it.stitching_app,
            spark_app_entrypoint: 'org.janelia.stitching.ConvertCZITilesToN5Spark',
            spark_app_args: czi_to_n5_args,
            spark_app_log: 'czi2n5.log'
        ]
    } \
    | run_czi2n5 \
    | terminate_stitching \
    | set { done }

    emit:
    done
}
