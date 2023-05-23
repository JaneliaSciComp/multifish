#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {
    default_spark_params;
} from './external-modules/spark/lib/param_utils'

include {
    default_mf_params;
    set_derived_defaults;
    get_value_or_default;
    get_list_or_default;
    stitching_container_param;
    airlocalize_container_param;
    segmentation_container_param;
    registration_container_param;
    stitching_ref_param;
    airlocalize_xy_stride_param;
    airlocalize_xy_overlap_param;
    airlocalize_z_stride_param;
    airlocalize_z_overlap_param;
    registration_xy_stride_param;
    registration_xy_overlap_param;
    registration_z_stride_param;
    registration_z_overlap_param;
    spots_assignment_container_param;
} from './param_utils'

// app parameters
final_params = set_derived_defaults(default_spark_params() + default_mf_params() + params, params)

include {
    download;
    publish;
} from './processes/downloader' addParams(final_params)

stitching_params = final_params + [
    stitching_container: stitching_container_param(final_params),
]
include {
    stitching;
} from './workflows/stitching' addParams(stitching_params)

airlocalize_params = final_params + [
    airlocalize_container: airlocalize_container_param(final_params),
    airlocalize_xy_stride: airlocalize_xy_stride_param(final_params),
    airlocalize_xy_overlap: airlocalize_xy_overlap_param(final_params),
    airlocalize_z_stride: airlocalize_z_stride_param(final_params),
    airlocalize_z_overlap: airlocalize_z_overlap_param(final_params),
]
include {
    spot_extraction;
} from './workflows/spot_extraction' addParams(airlocalize_params)

segmentation_params = final_params + [
    segmentation_container: segmentation_container_param(final_params)
]
include {
    segmentation;
} from './workflows/segmentation' addParams(segmentation_params)

registration_params = final_params + [
    registration_container: registration_container_param(final_params),
]
include {
    registration;
} from './workflows/registration' addParams(registration_params)

include {
    warp_spots;
    collect_merge_points;
} from './workflows/warp_spots' addParams(registration_params)

spot_assignment_params = final_params + [
    spots_assignment_container: spots_assignment_container_param(final_params),
]
include {
    measure_intensities;
} from './processes/spot_intensities' addParams(spot_assignment_params)

include {
    assign_spots;
} from './processes/spot_assignment' addParams(spot_assignment_params)

data_manifest = final_params.data_manifest
data_dir = final_params.data_dir
pipeline_output_dir = final_params.output_dir

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
resolution = final_params.resolution
axis_mapping = final_params.axis

steps_to_skip = get_list_or_default(final_params, 'skip', [])

// if stitching is not desired include 'stitching' in the 'skip' parameter
// or if stitching is needed for a different set 
// than 'acq_names' parameter set 'stitch_acq_names' parameter
acq_names = get_list_or_default(final_params, 'acq_names', [])
ref_acq = final_params.ref_acq
channels = get_list_or_default(final_params, 'channels',[])

log.info """
    ===================================
    EASI-FISH ANALYSIS PIPELINE
    ===================================
    
    Pipeline parameters
    -------------------
    workDir                : ${workDir}
    data_manifest          : ${data_manifest}
    shared_work_dir        : ${final_params.shared_work_dir}
    segmentation_model_dir : ${final_params.segmentation_model_dir}
    data_dir               : ${data_dir}
    output_dir             : ${pipeline_output_dir}
    publish_dir            : ${final_params.publish_dir}
    acq_names              : ${acq_names}
    channels               : ${channels}
    ref_acq                : ${ref_acq}
    steps_to_skip          : ${steps_to_skip}
    """
    .stripIndent()

if (steps_to_skip.contains('stitching')) {
    stitch_acq_names = []
} else {
    stitch_acq_names = get_list_or_default(final_params, 'stitch_acq_names', acq_names)
}
log.debug "Images to stitch: ${stitch_acq_names}"

stitching_block_size = final_params.stitching_block_size
retile_z_size = final_params.retile_z_size
stitching_ref = stitching_ref_param(final_params)
stitching_mode = final_params.stitching_mode
stitching_padding = final_params.stitching_padding
stitching_blur_sigma = final_params.stitching_blur_sigma
stitching_czi_pattern = final_params.stitching_czi_pattern

// if spot extraction is not desired include 'spot_extraction' in the 'skip' parameter 
if (steps_to_skip.contains('spot_extraction')) {
    spot_extraction_acq_names = []
} else {
    spot_extraction_acq_names = get_list_or_default(final_params, 'spot_extraction_acq_names', acq_names)
}
log.debug "Images for spot extraction: ${spot_extraction_acq_names}"
bleedthrough_channels = final_params.bleed_channel?.split(',')
spot_channels = channels - [final_params.dapi_channel]
log.debug  "Channels for spot detection: ${spot_channels}"

// if segmentation is not desired do not set segmentation_acq_name or ref_acq in the command line
if (steps_to_skip.contains('segmentation')) {
    segmentation_acq_names = []
} else {
    def segmentation_acq_name = get_value_or_default(final_params, 'segmentation_acq_name', ref_acq)
    segmentation_acq_names = segmentation_acq_name ? [ segmentation_acq_name ] : []
}
log.debug "Images for segmentation: ${segmentation_acq_names}"
segmentation_output = final_params.segmentation_output

if (steps_to_skip.contains('registration')) {
    registration_fixed_acq_names = []
    registration_moving_acq_names = []
} else {
    def registration_fixed_acq_name = get_value_or_default(final_params, 'registration_fixed_acq_name', ref_acq)
    if (!registration_fixed_acq_name) {
        log.error "No fixed image was specified for the registration"
        System.exit(1)
    }
    registration_fixed_acq_names = [ registration_fixed_acq_name ]
    registration_moving_acq_names = get_list_or_default(final_params, 'registration_moving_acq_names', acq_names-registration_fixed_acq_names)
}
log.debug "Images to register: ${registration_moving_acq_names} against ${registration_fixed_acq_names}"

if (steps_to_skip.contains('warp_spots')) {
    warp_spots_acq_names = []
} else {
    def registration_fixed_acq_name = get_value_or_default(final_params, 'registration_fixed_acq_name', ref_acq)
    if (!registration_fixed_acq_name) {
        log.error "No fixed image was specified for the warping spots"
        System.exit(1)
    }
    registration_fixed_acq_names = [ registration_fixed_acq_name ]
    warp_spots_acq_names = get_list_or_default(final_params, 'warp_spots_acq_names', acq_names-[registration_fixed_acq_name])
}
log.debug "Images for warping spots: ${warp_spots_acq_names}"

def labeled_spots_acq_name = get_value_or_default(final_params, 'labeled_spots_acq_name', ref_acq)
labeled_spots_acq_names = labeled_spots_acq_name ? [labeled_spots_acq_name ] : []

if (steps_to_skip.contains('measure_intensities')) {
    measure_acq_names = []
} else {
    if (!labeled_spots_acq_names) {
        log.error "No labeled image was specified for measuring intensities"
        System.exit(1)
    }
    measure_acq_names = get_list_or_default(final_params, 'measure_acq_names', acq_names)
}
log.debug "Images for intensities measurement: ${measure_acq_names}"

if (steps_to_skip.contains('assign_spots')) {
    assign_spots_acq_names = []
} else {
    if (!labeled_spots_acq_names) {
        log.error "No labeled image was specified for assigning spots"
        System.exit(1)
    }
    assign_spots_acq_names = get_list_or_default(final_params, 'assign_spots_acq_names', acq_names)
}
log.debug "Images for assign spots: ${assign_spots_acq_names}"

workflow {
    // download
    def data_dir_res = Channel.of(data_dir)
    if (data_manifest) {
        if (data_manifest.startsWith('/')) {
            manifest_file = data_manifest
        } else {
            manifest_file = "${projectDir}/data-sets/${data_manifest}.txt"
        }
        data_dir_res = download(Channel.of([file(manifest_file), final_params.data_dir]))
    }

    // stitching
    def stitching_results = stitching(
        stitching_app,
        stitch_acq_names,
        data_dir_res.first(),
        pipeline_output_dir,
        final_params.stitching_output,
        channels,
        resolution,
        axis_mapping,
        stitching_block_size,
        retile_z_size,
        stitching_ref, // stitching_ref or dapi_channel
        stitching_mode,
        stitching_padding,
        stitching_blur_sigma,
        stitching_czi_pattern,
        spark_conf,
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        gb_per_core,
        driver_cores,
        driver_memory,
        driver_logconfig
    ) // [ acq, stitching_dir ]
    stitching_results.subscribe { log.debug "Stitching results: $it" }

    // in order to allow users to skip stitching - if that is already done
    // we build a channel of expected stitched results which we 
    // concatenate to the actual stitched results and then filter them
    // for uniqueness in order to do the step only once for for an acq

    // prepare spot extraction inputs
    def spot_extraction_inputs = get_stitched_inputs_for_step(
        pipeline_output_dir,
        spot_extraction_acq_names,
        final_params.stitching_output,
        stitching_results
    )
    spot_extraction_inputs.subscribe { log.debug "Spot extraction input: $it" }

    def spot_extraction_output_dirs = get_step_output_dirs(
        spot_extraction_inputs,
        pipeline_output_dir,
        final_params.spot_extraction_output
    )

    // run spot extraction
    def spot_extraction_results = spot_extraction(
        spot_extraction_inputs.map { "${it[1]}/export.n5" },
        spot_extraction_output_dirs,
        spot_channels,
        bleedthrough_channels
    ) // [ input_image, ch, scale, spots_file ]
    spot_extraction_results.subscribe { log.debug "Spot extraction results: $it" }

    // prepare segmentation  inputs
    def segmentation_inputs = get_stitched_inputs_for_step(
        pipeline_output_dir,
        segmentation_acq_names,
        final_params.stitching_output,
        stitching_results
    )

    def segmentation_output_dirs = get_step_output_dirs(
        segmentation_inputs,
        pipeline_output_dir,
        segmentation_output
    )

    // run segmentation
    def segmentation_results = segmentation(
        segmentation_inputs.map { "${it[1]}/export.n5" },
        segmentation_inputs.map { "${it[0]}" },
        segmentation_output_dirs,
        final_params.dapi_channel,
        final_params.segmentation_scale,
        final_params.segmentation_model_dir
    )  // [ input_image_path, output_labels_tiff ]
    segmentation_results.subscribe { log.debug "Segmentation results: $it" }

    // prepare fixed and  moving inputs for the registration
    def registration_fixed_inputs = get_stitched_inputs_for_step(
        pipeline_output_dir,
        registration_fixed_acq_names,
        final_params.stitching_output,
        stitching_results
    )
    registration_fixed_inputs.subscribe { log.debug "Fixed registration input: $it" }

    def registration_moving_inputs = get_stitched_inputs_for_step(
        pipeline_output_dir,
        registration_moving_acq_names,
        final_params.stitching_output,
        stitching_results
    )
    registration_moving_inputs.subscribe { log.debug "Moving registration input: $it" }

    def registration_inputs = registration_fixed_inputs.combine(registration_moving_inputs) | map {
        log.debug "Create registration input for $it"
        def fixed_acq = it[0]
        def moving_acq = it[2]
        def registration_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.registration_output}/${moving_acq}-to-${fixed_acq}"
        )
        log.debug "Registration output for ${moving_acq} to ${fixed_acq} -> ${registration_output_dir}"
        def r = [
            "${fixed_acq}",
            "${it[1]}/export.n5", // stitching export for fixed acq
            "${moving_acq}",
            "${it[3]}/export.n5", // stitching export for moving acq
            "${registration_output_dir}" // pass it as string to be consistent, otherwise if types differ channel joins will not work properly
        ]
        log.debug "Registration inputs for channels ${channels}: $it -> $r"
        r
    }

    // run registration
    def registration_results =  registration(
        registration_inputs,
        final_params.dapi_channel, // dapi channel used to calculate all transformations
        registration_xy_stride_param(final_params),
        registration_xy_overlap_param(final_params),
        registration_z_stride_param(final_params),
        registration_z_overlap_param(final_params),
        final_params.aff_scale,
        final_params.def_scale,
        final_params.spots_cc_radius,
        final_params.spots_spot_number,
        final_params.ransac_cc_cutoff,
        final_params.ransac_dist_threshold,
        final_params.deform_iterations,
        final_params.deform_auto_mask,
        channels
    )

    // Take moving subpath (e.g. /c0/s2) extract the components (e.g. c0, s2) and add them to the end of the tuple
    def extended_registration_results = registration_results | map {
        // extract the channel from the registration results
        def moving_subpath_components = it[3].tokenize('/')
        // [
        //   <fixed>, <fixed_subpath>,
        //   <moving>, <moving_subpath>,
        //   <direct_transform>, <inv_transform>,
        //   <warped_path>,
        //   <warped_channel>, <warped_scale>
        // ]
        def r = it + [ moving_subpath_components[0], moving_subpath_components[1] ]
        log.debug "Extended registration result: $r"
        return r
    }

    // prepare inputs for warping spots
    def existing_spots_files = Channel.fromList(warp_spots_acq_names)
    | map {
        def acq_name = it
        get_step_output_dir(
            get_acq_output(pipeline_output_dir, acq_name),
            final_params.spot_extraction_output
        )
    }
    | collect_merge_points // [ spots_file_dir, spots_file ]

    existing_spots_files.subscribe { log.debug "Collected spots files $it" }

    def expected_spot_extraction_results = Channel.fromList(warp_spots_acq_names)
    | map {
        def acq_name = it
        def acq_stitching_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, acq_name),
            "${final_params.stitching_output}"
        )
        def acq_spot_extraction_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, acq_name),
            final_params.spot_extraction_output
        )
        [ acq_spot_extraction_output_dir, acq_stitching_output_dir ]
    }
    | combine(existing_spots_files, by: 0) // [ spots_file_dir, stitching_dir, spots_file ]
    | map {
        def (acq_spot_extraction_output_dir, acq_stitching_output_dir, spots_filepath) = it
        def spots_file = file(spots_filepath)
        def spots_filename_comps = spots_file.name.replace('.txt', '').tokenize('_')
        def spots_channel = spots_filename_comps[2]
        def d = [
            "${acq_stitching_output_dir}/export.n5",
            spots_channel,
            final_params.spot_extraction_scale,
            spots_filepath
        ]
        log.debug "Existing spots file: $d"
        d
    }

    // if spots were extracted as part of the current pipeline 
    // they should be available once spot_extraction_results complete
    // otherwise they should have been done already and 
    // they are provided by expected_spot_extraction_results
    def spots_to_warp = spot_extraction_results  
    | concat(expected_spot_extraction_results)
    // | unique {
    //     it[0..2].collect { "$it" }
    // }
    | map {
        // input, channel, scale, spots_microns, spots_voxels
        def r = [ it[0], it[1], it[3] ]
        log.debug "Extracted spots to warp: $r"
        return r
    } // [ n5_image_path, channel, spots_filepath]

    // prepare inputs for warping the spots
    def expected_registration_for_warping_spots = Channel.fromList(registration_fixed_acq_names)
    | combine(warp_spots_acq_names)
    | combine(spot_channels)
    | map {
        def fixed_acq = it[0]
        def moving_acq = it[1]
        def ch = it[2]
        def fixed_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, fixed_acq),
            "${final_params.stitching_output}"
        )
        def moving_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.stitching_output}"
        )
        def registration_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.registration_output}/${moving_acq}-to-${fixed_acq}"
        )
        def r = [
            "${fixed_dir}/export.n5", // fixed stitched image
            "/${ch}/${final_params.def_scale}", // channel/deform scale
            "${moving_dir}/export.n5", // moving stitched image
            "/${ch}/${final_params.def_scale}", // channel/deform scale
            "${registration_dir}/transform", // transform path
            "${registration_dir}/invtransform", // inv transform path
            "${registration_dir}/warped", // warped path
            ch,
            final_params.def_scale
        ]
        log.debug "Expected registration for warping spots: $r"
        r
    }

    def warp_spots_inputs = extended_registration_results
    | concat(expected_registration_for_warping_spots)
    | unique {
        log.debug "Registration results used for warping spots: $it"
        it[0..3].collect { "$it" }
    }
    | map {
        def fixed_stitched_results = file(it[0])
        def moving_stitched_results = file(it[2])
        def fixed_acq = fixed_stitched_results.parent.parent.name
        def moving_acq = moving_stitched_results.parent.parent.name
        def warped_spots_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.spot_extraction_output}/${moving_acq}-to-${fixed_acq}"
        )
        log.debug "Warped spots output for ${moving_acq} to ${fixed_acq} -> ${warped_spots_output_dir}"
        def r = [
            it[2], // moving
            it[7], // channel
            it[3], // moving subpath
            it[0], // fixed
            it[1], // fixed subpath
            it[5], // inv transform
            warped_spots_output_dir
        ]
        log.debug "Registration result to be combined with extracted spots result: $it -> $r"
        return r
    } 
    | combine(spots_to_warp, by:[0,1]) | map {
        // combined registration result by input and channel:
        // [ moving, channel, moving_subpath, fixed, fixed_subpath, inv_transform, warped_spots_output, spots_file]
        def spots_file =  file(it[7])
        def warped_spots_fname = spots_file.name.replace('.txt', '_warped.txt')
        def r = [
            it[3], // fixed
            it[4], // fixed subpath
            it[0], // moving
            it[2], // moving subpath
            it[5], // inv transform subpath
            "${it[6]}/${warped_spots_fname}", // warped spots file
            "${spots_file}" // spots file path (as string)
        ]
        log.debug "Prepare warp spots input $it -> $r"
        r
    }

    // run warp spots
    def warp_spots_results = warp_spots(
        warp_spots_inputs.map { it[0] }, // fixed
        warp_spots_inputs.map { it[1] }, // fixed_subpath
        warp_spots_inputs.map { it[2] }, // moving
        warp_spots_inputs.map { it[3] }, // moving_subpath
        warp_spots_inputs.map { it[4] }, // transform path
        warp_spots_inputs.map { it[5] }, // warped spots output
        warp_spots_inputs.map { it[6] }, // spots file path
    ) // [ warped_spots_file, subpath ]

    def expected_segmentation_results = Channel.fromList(labeled_spots_acq_names) | map {
        def acq_name = it
        def acq_stitching_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, acq_name),
            "${final_params.stitching_output}"
        )
        def acq_segmentation_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, acq_name),
            segmentation_output
        )
        [
            "${acq_stitching_output_dir}/export.n5",
            "${acq_segmentation_output_dir}/${acq_name}-${final_params.dapi_channel}.tif"
        ]
    }

    def labeled_acquisitions = segmentation_results
    | concat(expected_segmentation_results)
    | unique {
        "${it[0]}"
    } // [ stitched_n5_image, labels_tiff_image]

    // prepare intensities measurements inputs
    def expected_registrations_for_intensities = Channel.fromList(labeled_spots_acq_names)
    | combine(measure_acq_names)
    | combine(spot_channels)
    | map {
        def fixed_acq = it[0]
        def moving_acq = it[1]
        def ch = it[2]
        def fixed_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, fixed_acq),
            "${final_params.stitching_output}"
        )
        def moving_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.stitching_output}"
        )
        def registration_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.registration_output}/${moving_acq}-to-${fixed_acq}"
        )
        def r = [
            "${fixed_dir}/export.n5", // fixed stitched image
            "/${ch}/${final_params.def_scale}", // channel/deform scale
            "${moving_dir}/export.n5", // moving stitched image
            "/${ch}/${final_params.def_scale}", // channel/deform scale
            "${registration_dir}/transform", // transform path
            "${registration_dir}/invtransform", // inv transform path
            "${registration_dir}/warped", // warped path
            ch,
            final_params.def_scale,
            fixed_acq,
            moving_acq
        ]
        log.debug "Measure intensities input candidate: $it -> $r"
        r
    }

    def intensities_inputs_for_fixed = expected_registrations_for_intensities
    | filter {
        it[9] == it[10] // filter the expected registration that have the same fixed and moving source
    } | map {
        [ it[0], it[7], it[8] ] // [ fixed_image, ch, deformation_scale ]
    } | combine(labeled_acquisitions) | map {
        // [fixed, ch, def_scale, labels_input, labels_tiff ]
        def fixed_stitched_results = file(it[0])
        def fixed_acq = fixed_stitched_results.parent.parent.name
        def measure_intensities_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, fixed_acq),
            final_params.measure_intensities_output
        )
        log.debug "Intensities output for ${fixed_acq} -> ${measure_intensities_output_dir}"
        def r = [
            it[4], // labels
            it[0], // fixed stitched image
            fixed_acq, // intensity measurements result file prefix (round name)
            it[1], // channel
            it[2], // scale
            measure_intensities_output_dir // result output dir
        ]
        log.debug "Measure intensities inputs for fixed image: $it -> $r"
        return r;
    }

    def expected_intensities_for_moving = expected_registrations_for_intensities
    | filter { it[9] != it[10] }
    | map { it[0..8] }

    def intensities_inputs = extended_registration_results
    | filter {
        it[7] != final_params.dapi_channel
    }
    | concat(expected_intensities_for_moving)
    | unique {
        it[0..3].collect { "$it" }
    }
    | combine(labeled_acquisitions, by:0)
    | map {
        // so far we appended the corresponding labels to the registration result
        def fixed_stitched_results = file(it[0])
        def fixed_acq = fixed_stitched_results.parent.parent.name
        def moving_stitched_results = file(it[2])
        def moving_acq = moving_stitched_results.parent.parent.name
        def intensities_name = "${moving_acq}-to-${fixed_acq}"
        def measure_intensities_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.measure_intensities_output}/${intensities_name}"
        )
        log.debug "Measure intensities output for ${moving_acq} to ${fixed_acq} -> ${measure_intensities_output_dir}"
        if (it[8] != final_params.segmentation_scale) {
            log.warn "Warped image and labels must have the same shape so deform and segmentation scale should be the same"
        }
        def r = [
            it[9], // labels
            it[6], // warped spots image
            intensities_name, // intensity measurements result file prefix (round name)
            it[7], // channel
            final_params.segmentation_scale, // scale - must be same as segmentation scale
            measure_intensities_output_dir // result output dir
        ]
        log.debug "Measure intensities inputs for moving image $it -> $r"
        r
    }
    | concat(intensities_inputs_for_fixed)
    | unique {
        [ "${it[0]}", "${it[1]}", "${it[3]}", "${it[4]}" ]
    }
    | filter {
        // if skipping measure_intensities - filter out everything
        !steps_to_skip.contains('measure_intensities')
    }

    // run intensities measurements
    def intensities_results = measure_intensities(
        intensities_inputs.map { it[0] }, // labels
        intensities_inputs.map { it[1] }, // warped spots image
        intensities_inputs.map { it[2] }, // intensity measurements result file prefix (round name)
        intensities_inputs.map { it[3] }, // channel
        intensities_inputs.map { it[4] }, // scale
        intensities_inputs.map { it[5] }, // result output dir
        final_params.dapi_channel, // dapi_channel
        final_params.bleed_channel, // bleed_channel
        final_params.measure_intensities_cpus, // cpus
    )

    // prepare inputs for assign spots
    def expected_assign_spots = Channel.fromList(labeled_spots_acq_names)
    | combine(assign_spots_acq_names)
    | combine(spot_channels)
    | map {
        def fixed_acq = it[0]
        def moving_acq = it[1]
        def fixed_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, fixed_acq),
            "${final_params.stitching_output}"
        )
        def moving_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.stitching_output}"
        )
        def registration_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.registration_output}/${moving_acq}-to-${fixed_acq}"
        )
        if (fixed_acq != moving_acq) {
            def warped_spots_dir = get_step_output_dir(
                get_acq_output(pipeline_output_dir, moving_acq),
                "${final_params.spot_extraction_output}/${moving_acq}-to-${fixed_acq}"
            )
            [
                "${fixed_dir}/export.n5", // fixed stitched image
                "/${it[2]}/${final_params.def_scale}", // channel/deform scale
                "${moving_dir}/export.n5", // moving stitched image
                "/${it[2]}/${final_params.def_scale}", // channel/deform scale
                "${registration_dir}/invtransform", // transform path
                "${warped_spots_dir}/spots_${it[2]}_warped.txt",
                fixed_acq,
                moving_acq
            ]
        } else {
            def spots_dir = get_step_output_dir(
                get_acq_output(pipeline_output_dir, moving_acq),
                final_params.spot_extraction_output
            )
            [
                "${fixed_dir}/export.n5", // fixed stitched image
                "/${it[2]}/${final_params.def_scale}", // channel/deform scale
                "${moving_dir}/export.n5", // moving stitched image
                "/${it[2]}/${final_params.def_scale}", // channel/deform scale
                '', // no transform path
                "${spots_dir}/spots_${it[2]}.txt",
                fixed_acq,
                moving_acq
            ]
        }
    }

    def assign_spots_inputs_for_fixed = expected_assign_spots
    | filter { it[6] == it[7] }
    | map {
        def fixed_acq = it[6]
        def spots_file = file(it[5])
        def assign_spots_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, fixed_acq),
            final_params.assign_spots_output
        )
        log.debug "Assign spots output for ${fixed_acq} -> ${assign_spots_output_dir}"
        [ spots_file.parent, assign_spots_output_dir] // [ spots_dir, assigned_dir ]
    }
    | combine(labeled_acquisitions)
    | map {
        def r = [
            it[3], it[0], it[1], it[2], "/${final_params.dapi_channel}/${final_params.segmentation_scale}"
        ]
        log.debug "Assign spots input for fixed image: $it -> $r"
        return r
    } // [ label, spots_dir, assigned_dir, n5_file, subpath ]

    def expected_assign_spots_for_moving = expected_assign_spots
    | filter { it[6] != it[7] }
    | map { it[0..5] }

    def assign_spots_inputs = warp_spots_inputs
    | map {
        [
            it[5], // warped spots output
            it[0], // fixed
            it[1], // fixed_subpath
            it[2], // moving
            it[3], // moving_subpath
            it[4] // transform path
        ]
    }
    | filter {
        def (warped_spots_output_name,
            fixed_acq,
            fixed_subpath,
            moving_acq,
            moving_subpath) = it
        assign_spots_acq_names.contains(fixed_acq) ||
        assign_spots_acq_names.contains(moving_acq)
    }
    | combine(warp_spots_results, by:0)
    | map {
        // swap  again the fixed input in order 
        // to combine it with segmentation results which are done only for fixed image
        it[1..5] + [ it[0] ]
    }
    | concat(expected_assign_spots_for_moving)
    | unique {
        it.collect { "$it" }
    }
    | combine(labeled_acquisitions, by:0) | map {
        log.debug "Prepare spot assignment input from $it"
        def fixed_stitched_results = file(it[0])
        def fixed_acq = fixed_stitched_results.parent.parent.name
        def moving_stitched_results = file(it[2])
        def moving_subpath = it[3]
        def moving_acq = moving_stitched_results.parent.parent.name
        def assign_spots_output_dir = get_step_output_dir(
            get_acq_output(pipeline_output_dir, moving_acq),
            "${final_params.assign_spots_output}/${moving_acq}-to-${fixed_acq}"
        )
        log.debug "Spots assignment output for ${moving_acq} to ${fixed_acq} -> ${assign_spots_output_dir}"
        def warped_spots_file = file(it[5])
        def warped_spots_dir = warped_spots_file.parent
        def r = [
            it[6], // segmentation labels (TIFF)
            warped_spots_dir, // warped spots dir
            assign_spots_output_dir, // assignment output dir
            moving_stitched_results,
            moving_subpath
        ]
        log.debug "Assign spots input for warped spots: $it -> $r"
        return r
    } | concat(assign_spots_inputs_for_fixed) | unique { "$it" }

    // run assign spots
    def assign_spots_results = assign_spots(
        assign_spots_inputs.map { it[0] },
        assign_spots_inputs.map { it[1] },
        assign_spots_inputs.map { it[2] },
        assign_spots_inputs.map { it[3] },
        assign_spots_inputs.map { it[4] }
    )

    // publish all data
    if (final_params.publish_dir) {
        assign_spots_results 
            | collect
            | map { [pipeline_output_dir, final_params.publish_dir] } 
            | publish
    }
}

def get_acq_output(output, acq_name) {
    new File(output, acq_name)
}

def get_step_output_dir(output_dir, step_output) {
    return step_output == null || step_output == ''
        ? output_dir
        : (new File(output_dir, step_output)).absolutePath
}

def get_stitched_inputs_for_step(output_dir, step_acq_names, stitching_output, stitching_results) {
    def expected_stitched_results = Channel.fromList(step_acq_names) | map {
        [ 
            it,
            get_step_output_dir(
                get_acq_output(output_dir, it),
                stitching_output
            )
        ]
    }
    stitching_results
    | filter {
        step_acq_names.contains(it[0])
    } | concat(expected_stitched_results) | unique {
        it.collect { "$it" }
    }
}

def get_step_output_dirs(stitched_acqs, output_dir, step_output_name) {

    step_output_dirs = stitched_acqs | map {
        def acq_name = it[0]
        def step_output_dir = get_step_output_dir(
            get_acq_output(output_dir, acq_name),
            step_output_name
        )
        log.debug "Create ${step_output_name} output for ${acq_name} -> ${step_output_dir}"
        return step_output_dir
    }

}
