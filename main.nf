#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

// app parameters
params.stitching_app = 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar'
params.stitching_output = ''
params.resolution = '0.23,0.23,0.42'
params.axis = '-x,y,z'
params.acq_names = ''
params.channels = 'c0 c1 c2 c3'
params.block_size = '128,128,64'
params.registration_channel = '2'
params.stitching_mode = 'incremental'
params.stitching_padding = '0,0,0'
params.blur_sigma = '2'

final_params = default_spark_params() + params

include {
    stitching;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

// spark config
spark_conf = final_params.spark_conf
spark_work_dir = final_params.spark_work_dir
spark_workers = final_params.workers
spark_worker_cores = final_params.worker_cores
gb_per_core = final_params.gb_per_core
driver_cores = final_params.driver_cores
driver_memory = final_params.driver_memory
driver_logconfig = final_params.driver_logconfig

stitching_app = final_params.stitching_app
stitching_output = final_params.stitching_output
data_dir = final_params.data_dir
resolution = final_params.resolution
axis_mapping = final_params.axis
acq_names = Channel.fromList(final_params.acq_names?.tokenize(' '))
channels = final_params.channels?.tokenize(' ')
block_size = final_params.block_size
registration_channel = final_params.registration_channel
stitching_mode = final_params.stitching_mode
stitching_padding = final_params.stitching_padding
blur_sigma = final_params.blur_sigma

workflow {
    acq_names \
    | map { acq_name ->
        println "Prepare stitching for $acq_name"
        [
            stitching_app: stitching_app,
            stitching_output: stitching_output,
            data_dir: data_dir,
            acq_name: acq_name,
            channels: channels,
            resolution: resolution,
            axis_mapping: axis_mapping,
            block_size: block_size,
            registration_channel: registration_channel,
            stitching_mode: stitching_mode,
            stitching_padding: stitching_padding,
            blur_sigma: blur_sigma,
            spark_conf: spark_conf,
            spark_work_dir: "${spark_work_dir}/${acq_name}",
            spark_workers: spark_workers,
            spark_worker_cores: spark_worker_cores,
            spark_executor_cores: spark_worker_cores,
            spark_gbmem_per_core: gb_per_core,
            spark_driver_cores: driver_cores,
            spark_driver_memory: driver_memory,
            spark_driver_logconfig: driver_logconfig
        ]
    } \
    | stitching \
    | view
}
