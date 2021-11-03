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

    def rsfish_args = indexed_input_dirs
    | join(indexed_output_dirs) // [index, input_dir, output_dir]
    | combine(spot_channels) // [index, input_dir, output_dir, channel]
    | map {
        def (index, input_dir, output_dir, channel) = it
        def acq_name = file(input_dir).parent.parent.name
        def output_file = "${output_dir}/rsfish_points_${channel}.csv"
        [
            "--image=${input_dir} --dataset=/${channel}/${scale} --minIntensity=0 --maxIntensity=4096 --anisotropy=0.7 --output=${output_file}",
            cluster_work_dir,
            "rsFISH_${acq_name}_${channel}.log",
            output_file
        ]
    } // [ args, cluster_work_dir, log_name, output_file ]
    | combine(spark_cluster_res, by:1) // [ cluster_work_dir, args, log_name, output_file, spark_uri ]

    rsfish_args.subscribe {  log.debug "RS-FISH app args: $it"  }

    def rsfish_done = run_rsfish(
        rsfish_args.map { it[4] }, // spark URI
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
        | combine(rsfish_args) // [ cluster_work_dir, terminate_file_name, args, log_name, output_file, spark_uri ]
    postprocess_spots_inputs.subscribe {  log.debug "Post process spots args: $it"  }

    postprocess_spots = postprocess_spots(
        postprocess_spots_inputs.map { it[4] }
    )

    emit:
    postprocess_spots
}
