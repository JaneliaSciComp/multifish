#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

include {
    default_mf_params;
} from './param_utils'

// app parameters
params.output_dir = params.data_dir
params.acq_names = ''

final_params = default_spark_params() + default_mf_params() + params

include {
    stitching;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

include {
    spot_extraction;
} from './workflows/spot_extraction' addParams(lsf_opts: final_params.lsf_opts,
                                               mfrepo: final_params.mfrepo)

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
channels = final_params.channels?.tokenize(',')
block_size = final_params.block_size
registration_channel = final_params.registration_channel
stitching_mode = final_params.stitching_mode
stitching_padding = final_params.stitching_padding
blur_sigma = final_params.blur_sigma

spot_extraction_output = final_params.spot_extraction_output
air_localize_channel_params = final_params.air_localize_channel_params?.tokenize(',')
workflow {
    // stitching
    stitching_result = acq_names \
    | map { acq_name ->
        println "Prepare stitching for $acq_name"
        output_dir = new File(final_params.output_dir, acq_name)
        stitching_output_dir = stitching_output == null || stitching_output == ''
            ? output_dir
            : new File(output_dir, stitching_output)
        // create output dir
        stitching_output_dir.mkdirs()
        //  create the links
        mvl_link = new File(stitching_output_dir, "${acq_name}.mvl")
        if (!mvl_link.exists())
            java.nio.file.Files.createSymbolicLink(mvl_link.toPath(), new File(data_dir, "${acq_name}.mvl").toPath())
        czi_link = new File(stitching_output_dir, "${acq_name}.czi")
        if (!czi_link.exists())
            java.nio.file.Files.createSymbolicLink(czi_link.toPath(), new File(data_dir, "${acq_name}.czi").toPath())

        [
            stitching_app: stitching_app,
            data_dir: data_dir,
            output_dir: output_dir,
            stitching_output_dir: stitching_output_dir,
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
    | stitching

    // spot extraction
    stitching_result \
    | map {
        spot_extraction_output_dir = spot_extraction_output == null || spot_extraction_output == ''
            ? it.output_dir
            : new File(it.output_dir, spot_extraction_output)
        // create output dir
        spot_extraction_output_dir.mkdirs()
        it + [
            spot_extraction_output_dir: spot_extraction_output_dir
            xy_stride: it.spot_extraction_xy_stride,
            xy_overlap: it.spot_extraction_xy_overlap,
            z_stride: it.spot_extraction_z_stride,
            z_overlap: it.spot_extraction_z_overlap,
        ]
    } \
    | spot_extraction \
    | view
}
