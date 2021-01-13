#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

// app parameters
params.deconvrepo = 'registry.int.janelia.org/janeliascicomp'
params.stitching_app = 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar'
params.resolution = '0.104,0.104,0.18'
params.axis = '-y,-x,z'
params.channels = '488nm 560nm 642nm'
params.iterations_per_channel = '10 10 10'
params.block_size = '128,128,64'
params.psf_z_step_um = '0.1'
params.background = ''
params.deconv_cores = 4

final_params = default_spark_params() + params

include {
    pre_stitching;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

include {
    deconvolution
} from './workflows/deconvolution' addParams(lsf_opts: final_params.lsf_opts, 
                                             deconvrepo: final_params.deconvrepo)

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
psf_dir = file(final_params.psf_dir)
resolution = final_params.resolution
axis_mapping = final_params.axis
channels = final_params.channels?.tokenize(' ')
iterations_per_channel = final_params.iterations_per_channel?.tokenize(' ')
                .collect { it as int }
channels_psfs = channels.collect {
    ch = it.replace("nm", "")
    return "${psf_dir}/${ch}_PSF.tif"
}
block_size = final_params.block_size
psf_z_step_um = final_params.psf_z_step_um
background = final_params.background
deconv_cores = final_params.deconv_cores > 0 ? final_params.deconv_cores : 1

if( !spark_work_dir.exists() ) {
    spark_work_dir.mkdirs()
}

workflow {
    pre_stitching_res = pre_stitching(
        stitching_app,
        data_dir,
        resolution,
        axis_mapping,
        channels,
        block_size,
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        gb_per_core,
        driver_cores,
        driver_memory,
        driver_logconfig
    )
    deconv_res = deconvolution(
        pre_stitching_res, 
        channels,
        channels_psfs,
        psf_z_step_um,
        background,
        iterations_per_channel,
        deconv_cores)
    
    deconv_res | view
}
