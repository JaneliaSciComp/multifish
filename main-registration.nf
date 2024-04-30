#!/usr/bin/env nextflow
/*
    Image registration using Bigstream
*/
// path to the fixed n5 image
params.fixed = ""


// path to the moving n5 image
params.moving = ""

// path to the folder where you'd like all outputs to be written
params.outdir = ""

fixed = file(params.fixed)
moving = file(params.moving)
outdir = file(params.outdir)

transform_dir = "${outdir}/transform"
invtransform_dir = "${outdir}/invtransform"
warped_dir = "${outdir}/warped"

log.info """\
    REGISTRATION PIPELINE
    ===================================
    fixed           : $fixed
    moving          : $moving
    outdir          : $outdir
    transform       : $transform_dir
    invtransform    : $invtransform_dir
    warped          : $warped_dir
    workDir         : $workDir
    """
    .stripIndent()

include {
    default_mf_params;
    registration_container_param;
    registration_xy_stride_param;
    registration_xy_overlap_param;
    registration_z_stride_param;
    registration_z_overlap_param;
} from './param_utils'

final_params = default_mf_params() + params

include {
    registration;
} from './workflows/registration' addParams(lsf_opts: final_params.lsf_opts,
                                            registration_container: registration_container_param(final_params),
                                            aff_scale_transform_cpus: final_params.aff_scale_transform_cpus,
                                            def_scale_transform_cpus: final_params.def_scale_transform_cpus,
                                            registration_stitch_cpus: final_params.registration_stitch_cpus,
                                            registration_transform_cpus: final_params.registration_transform_cpus)

channels = final_params.channels?.split(',')

workflow {
    def fixed_name = final_params.fixed_name ?: fixed.name
    def moving_name = final_params.moving_name ?: moving.name
    def registration_input = Channel.of(
        [
            fixed_name,
            fixed,
            moving_name,
            moving,
            outdir,
        ]
    )
    registration(
        registration_input,
        final_params.dapi_channel,
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
        channels,
    )
}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

