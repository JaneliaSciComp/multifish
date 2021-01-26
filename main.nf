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

include {
    segmentation;
} from './workflows/segmentation' addParams(lsf_opts: final_params.lsf_opts,
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
acq_names = Channel.fromList(final_params.acq_names?.tokenize(','))
channels = final_params.channels?.split(',')
block_size = final_params.block_size
registration_channel = final_params.registration_channel
stitching_mode = final_params.stitching_mode
stitching_padding = final_params.stitching_padding
blur_sigma = final_params.blur_sigma

spot_extraction_output = final_params.spot_extraction_output
spot_extraction_dapi_correction_channels = final_params.spot_extraction_dapi_correction_channels?.split(',')
per_channel_air_localize_params = [
    channels,
    final_params.per_channel_air_localize_params?.split(',', -1)
].transpose()
 .inject([:]) { a, b ->
    ch = b[0]
    airlocalize_params = b[1] == null || b[1] == ''
        ? final_params.default_airlocalize_params
        : b[1]
    a[ch] =  airlocalize_params
    return a 
}

segmentation_output = final_params.segmentation_output

workflow {
    // stitching
    stitching_result = acq_names \
    | map { acq_name ->
        println "Prepare stitching for $acq_name"
        output_dir = get_acq_output(final_params.output_dir, acq_name)
        stitching_output_dir = get_step_output_dir(output_dir, stitching_output)
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
        spot_extraction_output_dir = get_step_output_dir(it.output_dir, spot_extraction_output)
        // create output dir
        spot_extraction_output_dir.mkdirs()
        it + [
            data_dir: "${it.stitching_output_dir}/export.n5",
            spot_extraction_output_dir: spot_extraction_output_dir,
            scale: final_params.scale_4_spot_extraction,
            xy_stride: final_params.spot_extraction_xy_stride,
            xy_overlap: final_params.spot_extraction_xy_overlap,
            z_stride: final_params.spot_extraction_z_stride,
            z_overlap: final_params.spot_extraction_z_overlap,
            dapi_channel: final_params.dapi_channel,
            dapi_correction_channels: spot_extraction_dapi_correction_channels,
            per_channel_air_localize_params:per_channel_air_localize_params,
        ]
    } \
    | spot_extraction \
    | view

    // segmentation
    stitching_result \
    | filter {
        it.acq_name == final_params.reference_acq_name
    } \
    | map {
        stitching_output_dir = get_step_output_dir(it.output_dir, stitching_output)
        segmentation_output_dir = get_step_output_dir(it.output_dir, segmentation_output)
        // create output dir
        segmentation_output_dir.mkdirs()
        it + [
            data_dir: "${stitching_output_dir}/export.n5",
            segmentation_output_dir: segmentation_output_dir,
            dapi_channel: final_params.dapi_channel
            scale: final_params.scale_4_segmentation,
            model_dir: final_params.segmentation_model_dir,
        ]
    } \
    | segmentation \
    | view
}

def get_acq_output(output, acq_name) {
    new File(output, acq_name)
}

def get_step_output_dir(output_dir, step_output) {
    return step_output == null || step_output == ''
        ? output_dir
        : new File(output_dir, step_output)
}
