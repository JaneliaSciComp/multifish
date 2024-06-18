include {
    prepare_spots_dirs;
    postprocess_spots;
} from '../processes/rs_fish'

include {
    spark_cluster;
    run_spark_app_on_existing_cluster as run_rsfish;
} from '../external-modules/spark/lib/workflows' addParams([
    spark_container_repo: params.rsfish_container_repo,
    spark_container_name: params.rsfish_container_name,
    spark_container_version: params.rsfish_container_version,
])

include {
    terminate_spark as terminate_rsfish;
} from '../external-modules/spark/lib/processes'

include {
    index_channel;
} from './utils'

include {
    get_list_or_default;
} from '../param_utils'

workflow rsfish {
    take:
    input_dirs
    output_dirs
    spot_channels
    scale
    dapi_channel
    bleedthrough_channels // currently ignored for RS-FISH processing

    main:
    def spark_driver_stack_size = ''
    def spark_driver_deploy_mode = ''
    def terminate_name = 'terminate-rsfish'

    def indexed_input_dirs = index_channel(input_dirs)
    def indexed_output_dirs = index_channel(output_dirs)

    indexed_input_dirs.subscribe { log.debug "Indexed input dir: $it" }
    indexed_output_dirs.subscribe { log.debug "Indexed output dir: $it" }
    
    def spots_output_dirs = prepare_spots_dirs(
        output_dirs // create dependency on stitching
    )

    // start a spark cluster
    def cluster_id = UUID.randomUUID()
    // TODO: using a random id here breaks the resume mechanism, so that rs-fish runs every time
    def cluster_work_dir = "${params.spark_work_dir}/${cluster_id}"
    def spark_cluster_res = spark_cluster(
        params.spark_conf,
        input_dirs | collect | map { cluster_work_dir }, // create dependency on stitching, so that the 
                                                         // spark cluster doesn't start until we're ready to use it
        params.rsfish_workers,
        params.rsfish_worker_cores,
        params.rsfish_gb_per_core,
        terminate_name
    )
    // print spark cluster result [ spark_uri, cluster_work_dir ]
    spark_cluster_res.subscribe {  log.debug "Spark cluster result: $it"  }

    def all_per_channels_params = get_all_per_channel_params(params)

    def rsfish_args = indexed_input_dirs
    | join(indexed_output_dirs) // [index, input_dir, output_dir]
    | combine(spot_channels) // [index, input_dir, output_dir, channel]
    | map {
        def (index, input_dir, output_dir, channel) = it
        def acq_name = file(input_dir).parent.parent.name
        def subpath = "/${channel}/${scale}"
        def output_voxel_file = "${output_dir}/spots_rsfish_${channel}.csv"
        def output_microns_file = "${output_dir}/spots_${channel}.txt"
        def minIntensity = all_per_channels_params.rsfish_min[channel]
        def maxIntensity = all_per_channels_params.rsfish_max[channel]
        def anisotropy = all_per_channels_params.rsfish_anisotropy[channel]
        def sigma = all_per_channels_params.rsfish_sigma[channel]
        def threshold = all_per_channels_params.rsfish_threshold[channel]
        def background = all_per_channels_params.rsfish_background[channel]
        def intensity = all_per_channels_params.rsfish_intensity[channel]
        def rsfish_cmd_args = [
            "--image=${input_dir} --dataset=${subpath} " +
            "--minIntensity=${minIntensity} " +
            "--maxIntensity=${maxIntensity} " +
            "--anisotropy=${anisotropy} " +
            "--sigma=${sigma} " +
            "--threshold=${threshold} " +
            "--background=${background} " +
            "--intensityMethod=${intensity} " +
            "--output=${output_voxel_file} ${params.rsfish_params}",
            cluster_work_dir,
            "rsFISH_${acq_name}_${channel}.log",
            input_dir,
            subpath,
            output_voxel_file,
            output_microns_file,
            channel,
            scale
        ]
        log.debug "RS-FISH command arguments for channel ${channel} -> ${rsfish_cmd_args}"
        rsfish_cmd_args
    } // [ args, cluster_work_dir, log_name, input_dir, subpath, output_voxel_file, output_microns_file, channel, scale ]
    | combine(spark_cluster_res, by:1) // [ cluster_work_dir, args, log_name, input_dir, subpath, output_voxel_file, output_microns_file, channel, scale, spark_uri ]

    rsfish_args.subscribe {  log.debug "RS-FISH app args: $it"  }

    def rsfish_done = run_rsfish(
        rsfish_args.map { it[9] }, // spark URI
        params.rs_fish_app,
        'net.preibisch.rsfish.spark.SparkRSFISH',
        rsfish_args.map { it[1] }, // app args
        rsfish_args.map { it[2] }, // log name
        terminate_name,
        params.spark_conf,
        rsfish_args.map { it[0] }, // spark working dir
        params.rsfish_workers,
        params.rsfish_worker_cores,
        params.rsfish_gb_per_core,
        params.rsfish_driver_cores,
        params.rsfish_driver_memory,
        spark_driver_stack_size,
        params.driver_logconfig,
        spark_driver_deploy_mode
    )

    // terminate rsfish cluster
    def rs_fish_results = terminate_rsfish(
        rsfish_done.collect().map { it[1] },
        terminate_name
    ) // [ terminate_file_name, cluster_work_dir ]

    def postprocess_spots_inputs = rs_fish_results 
        | map { it.reverse() } // [ cluster_work_dir, terminate_file_name ]
        | combine(rsfish_args, by:0) // [ cluster_work_dir, terminate_file_name, args, log_name, input_dir, subpath, output_voxel_file, output_microns_file, channel, scale, spark_uri ]
    postprocess_spots_inputs.subscribe {  log.debug "Post process spots args: $it"  }

    postprocess_spots = postprocess_spots(
        postprocess_spots_inputs.map { it[4] },
        postprocess_spots_inputs.map { it[8] },
        postprocess_spots_inputs.map { it[9] },
        postprocess_spots_inputs.map { it[6] },
        postprocess_spots_inputs.map { it[7] },
    ) // [ <input_image>, <ch>, <scale>, <spots_microns>, <spots_voxels> ]

    emit:
    postprocess_spots
}

def get_all_per_channel_params(Map ps) {
    [
        rsfish_min: get_param_values_per_channel(ps, 'rsfish_min'),
        rsfish_max: get_param_values_per_channel(ps, 'rsfish_max'),
        rsfish_anisotropy: get_param_values_per_channel(ps, 'rsfish_anisotropy'),
        rsfish_sigma: get_param_values_per_channel(ps, 'rsfish_sigma'),
        rsfish_threshold: get_param_values_per_channel(ps, 'rsfish_threshold'),
        rsfish_background: get_param_values_per_channel(ps, 'rsfish_background'),
        rsfish_intensity: get_param_values_per_channel(ps, 'rsfish_intensity'),
    ]
}

def get_param_values_per_channel(Map ps, String param_name) {
    def channels = get_list_or_default(ps, 'channels', [])
    def per_channel_params

    def source_per_channel_param_values = ps['per_channel'][param_name]
    if (source_per_channel_param_values == null ||
            source_per_channel_param_values instanceof String && source_per_channel_param_values.trim() == '' ||
            source_per_channel_param_values instanceof Boolean) {
        per_channel_params = []
    } else if (source_per_channel_param_values instanceof String) {
        per_channel_params =  ps['per_channel'][param_name].split(',').collect { it.trim() }
    } else {
        per_channel_params = [source_per_channel_param_values]
    }

    // the number of records that need to be filled
    def nremaining_values = channels.size - per_channel_params.size
    return [
        channels,
        nremaining_values > 0
            ? per_channel_params + [null] * nremaining_values
            : per_channel_params
    ]
    .transpose()
    .inject([:]) { param_values, ch_and_value ->
        def ch = ch_and_value[0]
        def param_value = ch_and_value[1] 
                            ? ch_and_value[1]
                            : ps[param_name]
        param_values[ch] = param_value
        return param_values
    }
}
