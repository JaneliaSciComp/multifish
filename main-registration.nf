#!/usr/bin/env nextflow
/*
    Image registration using Bigstream
*/
nextflow.enable.dsl=2

// path to the fixed n5 image
params.fixed = ""

// path to the moving n5 image
params.moving = ""

// path to the folder where you'd like all outputs to be written
params.outdir = ""

// the channel used to drive registration
params.channel = "c2"

// the scale level for affine alignments
params.aff_scale = "s3"

// the scale level for deformable alignments
params.def_scale = "s2"

// the number of voxels along x/y for registration tiling, must be power of 2
params.xy_stride = 256

// the number of voxels along z for registration tiling, must be power of 2
params.z_stride = 256

// spots params
params.spots_cc_radius="8"
params.spots_spot_number="2000"

// ransac params
params.ransac_cc_cutoff="0.9"
params.ransac_dist_threshold="2.5"

// deformation parameters
params.deform_iterations="500x200x25x1"
params.deform_auto_mask="0"

fixed = file(params.fixed)
moving = file(params.moving)
outdir = file(params.outdir)

affdir = file("${outdir}/aff")
if(!affdir.exists()) affdir.mkdirs()

tiledir = file("${outdir}/tiles")
if(!tiledir.exists()) tiledir.mkdirs()

aff_scale_subpath = "/${params.channel}/${params.aff_scale}"
def_scale_subpath = "/${params.channel}/${params.def_scale}"

// final outputs
transform_dir = "${outdir}/transform"
invtransform_dir = "${outdir}/invtransform"
warped_dir = "${outdir}/warped"


log.info """\
         BIGSTREAM REGISTRATION PIPELINE
         ===================================
         workDir         : $workDir
         outdir          : ${params.outdir}
         affdir          : $affdir
         tiledir         : $tiledir
         aff_scale       : $aff_scale_subpath
         def_scale       : $def_scale_subpath
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
                                            registration_container: registration_container_param(params),
                                            aff_scale_transform_cpus: final_params.aff_scale_transform_cpus,
                                            def_scale_transform_cpus: final_params.def_scale_transform_cpus,
                                            stitch_registered_cpus: final_params.stitch_registered_cpus,
                                            final_transform_cpus: final_params.final_transform_cpus)

workflow {

    registration(
        fixed,
        moving,
        outdir,
        final_params.channel,
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
        final_params.deform_auto_mask
    )
}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

