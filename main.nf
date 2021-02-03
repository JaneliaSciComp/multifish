#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

include {
    default_mf_params;
    get_acqs_for_step;
    get_value_or_alt;
    output_dir_param;
    spotextraction_container_param;
    segmentation_container_param;
    registration_container_param;
    spot_extraction_xy_stride_param;
    spot_extraction_xy_overlap_param;
    spot_extraction_z_stride_param;
    spot_extraction_z_overlap_param;
} from './param_utils'

// app parameters
params.output_dir = params.data_dir
params.acq_names = ''

final_params = default_spark_params() + default_mf_params() + params

include {
    stitch_multiple_acquisitions;
} from './workflows/stitching' addParams(lsf_opts: final_params.lsf_opts, 
                                         crepo: final_params.crepo,
                                         spark_version: final_params.spark_version)

include {
    spot_extraction;
} from './workflows/spot_extraction' addParams(lsf_opts: final_params.lsf_opts,
                                               spotextraction_container: spotextraction_container_param(final_params))

include {
    segmentation;
} from './workflows/segmentation' addParams(lsf_opts: final_params.lsf_opts,
                                            segmentation_container: segmentation_container_param(final_params))

include {
    prepare_fixed_acq;
    registration;
} from './workflows/registration' addParams(lsf_opts: final_params.lsf_opts,
                                            registration_container: registration_container_param(final_params),
                                            aff_scale_transform_cpus: final_params.aff_scale_transform_cpus,
                                            def_scale_transform_cpus: final_params.def_scale_transform_cpus,
                                            stitch_registered_cpus: final_params.stitch_registered_cpus,
                                            final_transform_cpus: final_params.final_transform_cpus)

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
data_dir = final_params.data_dir
resolution = final_params.resolution
axis_mapping = final_params.axis

// if stitching is not desired do not set 'stitch_acq_names' or acq_names in the command line parameters
stitch_acq_names = get_acqs_for_step(final_params, 'stitch_acq_names', 'acq_names')
channels = final_params.channels?.split(',')
block_size = final_params.block_size
registration_channel = final_params.registration_channel
stitching_mode = final_params.stitching_mode
stitching_padding = final_params.stitching_padding
blur_sigma = final_params.blur_sigma

// if spot extraction is not desired do not set spot_extraction_acq_names or acq_names in the command line parameters
spot_extraction_acq_names = get_acqs_for_step(final_params, 'spot_extraction_acq_names', 'acq_names')
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

// if segmentation is not desired do not set segmentation_acq_name or reference_acq_name in the command line
segmentation_acq_name = get_value_or_alt(final_params, 'segmentation_acq_name', 'reference_acq_name')
segmentation_acq_names = segmentation_acq_name ? [ segmentation_acq_name ] : []
segmentation_output = final_params.segmentation_output

prep_registration_fixed_acq_names = get_acqs_for_step(final_params, 'prep_registration_fixed_acq_name', 'acq_names')
prep_registration_fixed_output = final_params.prep_registration_fixed_output

registration_moving_acq_names = get_acqs_for_step(final_params, 'registration_moving_acq_names', 'acq_names')

workflow {
    // stitching
    def stitching_results = stitch_multiple_acquisitions(
        stitching_app,
        stitch_acq_names,
        final_params.data_dir,
        output_dir_param(final_params),
        final_params.stitching_output,
        channels,
        resolution,
        axis_mapping,
        block_size,
        registration_channel,
        stitching_mode,
        stitching_padding,
        blur_sigma,
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        gb_per_core,
        driver_cores,
        driver_memory,
        driver_logconfig
    )

    // in order to allow users to skip stitching - if that is already done
    // we build a channel of expected stitched results which we 
    // concatenate to the actual stitched results and then filter them
    // for uniqueness in order to do the step only once for for an acq

    def spot_extraction_inputs = get_stitched_inputs_for_step(
        spot_extraction_acq_names,
        final_params.stitching_output,
        stitching_results

    )

    def spot_extraction_output_dirs = get_step_output_dirs(
        spot_extraction_inputs,
        output_dir_param(final_params),
        spot_extraction_output
    )

    def spot_extraction_results = spot_extraction(
        spot_extraction_inputs.map { "${it[1]}/export.n5" },
        spot_extraction_output_dirs,
        channels,
        final_params.scale_4_spot_extraction,
        spot_extraction_xy_stride_param(final_params),
        spot_extraction_xy_overlap_param(final_params),
        spot_extraction_z_stride_param(final_params),
        spot_extraction_z_overlap_param(final_params),
        final_params.dapi_channel,
        spot_extraction_dapi_correction_channels,
        per_channel_air_localize_params
    )

    def segmentation_inputs = get_stitched_inputs_for_step(
        segmentation_acq_names,
        final_params.stitching_output,
        stitching_results
    )

    def segmentation_output_dirs = get_step_output_dirs(
        segmentation_inputs,
        output_dir_param(final_params),
        segmentation_output
    )

    def segmentation_results = segmentation(
        segmentation_inputs.map { "${it[1]}/export.n5" },
        segmentation_inputs.map { "${it[0]}" },
        segmentation_output_dirs,
        final_params.dapi_channel,
        final_params.scale_4_segmentation,
        final_params.segmentation_model_dir,
        final_params.predict_cpus
    )

    def prep_registration_fixed_inputs = get_stitched_inputs_for_step(
        prep_registration_fixed_acq_names,
        final_params.stitching_output,
        stitching_results
    )
    def prep_registration_fixed_output_dirs = get_step_output_dirs(
        prep_registration_fixed_inputs,
        output_dir_param(final_params),
        prep_registration_fixed_output
    )

    def prep_fixed_results =  prepare_fixed_acq(
        prep_registration_fixed_inputs.map { "${it[1]}/export.n5" },
        prep_registration_fixed_output_dirs,
        final_params.dapi_channel,
        final_params.def_scale, // retile at the deformation scale
        final_params.aff_scale, // for spots use affine scale
        final_params.spots_cc_radius,
        final_params.spots_spot_number
    )

    // def registration_moving_inputs = get_stitched_inputs_for_step(
    //     registration_moving_acq_names,
    //     final_params.stitching_output,
    //     stitching_results
    // )

    // def registration_results = registration(

    // )
}

def get_acq_output(output, acq_name) {
    new File(output, acq_name)
}

def get_step_output_dir(output_dir, step_output) {
    return step_output == null || step_output == ''
        ? output_dir
        : new File(output_dir, step_output)
}

def get_stitched_inputs_for_step(step_acq_names, stitching_output, stitching_results) {
    def expected_stitched_results = Channel.fromList(step_acq_names) | map {
        [ 
            it,
            get_step_output_dir(
                get_acq_output(output_dir_param(final_params), it),
                stitching_output
            )
        ]
    }
    stitching_results | concat(expected_stitched_results) | unique
}

def get_step_output_dirs(stitched_acqs, output_dir, step_output_name) {

    step_output_dirs = stitched_acqs | map {
        def acq_name = it[0]
        def step_output_dir = get_step_output_dir(
            get_acq_output(output_dir, acq_name),
            step_output_name
        )
        println "Create ${step_output_name} output for ${acq_name} -> ${step_output_dir}"
        step_output_dir.mkdirs()
        return step_output_dir
    }

}