#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

// app parameters
params.stitching_app = 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar'
params.resolution = '0.23,0.23,0.42'
params.axis = '-x,y,z'
params.acq_names = ''
params.channels = 'c0 c1 c2 c3'
params.block_size = '128,128,64'

final_params = default_spark_params() + params

include {
    stitching;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

// spark config
spark_conf = final_params.spark_conf
spark_work_dir = file(final_params.spark_work_dir)
spark_workers = final_params.workers
spark_worker_cores = final_params.worker_cores
gb_per_core = final_params.gb_per_core
driver_cores = final_params.driver_cores
driver_memory = final_params.driver_memory
driver_logconfig = final_params.driver_logconfig

stitching_app = file(final_params.stitching_app)
data_dir = file(final_params.data_dir)
resolution = final_params.resolution
axis_mapping = final_params.axis
acq_names = Channel.fromList(final_params.acq_names?.tokenize(' '))
channels = final_params.channels?.tokenize(' ')
block_size = final_params.block_size

if( !spark_work_dir.exists() ) {
    spark_work_dir.mkdirs()
}

workflow {
    acq_names \
    | map { acq_name ->
        println "Prepare stitching for $acq_name"
        [
            stitching_app: stitching_app,
            data_dir: data_dir,
            acq_name: acq_name,
            channels: channels,
            resolution: resolution,
            axis_mapping: axis_mapping,
            block_size: block_size,
            spark_conf: spark_conf,
            spark_work_dir: spark_work_dir,
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
