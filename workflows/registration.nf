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
params.reg_outdir = ""

// the channel used to drive registration
params.reg_chan = "c2"

// the scale level for affine alignments
params.reg_aff_scale = "s3"

// the scale level for deformable alignments
params.reg_def_scale = "s2"

// the number of voxels along x/y for registration tiling, must be power of 2
params.reg_xy_stride = 256

// the number of voxels along z for registration tiling, must be power of 2
params.reg_z_stride = 256

// spots params
params.reg_spots_cc_radius="8"
params.reg_spots_spot_number="2000"

// ransac params
params.reg_ransac_cc_cutoff="0.9"
params.reg_ransac_dist_threshold="2.5"

// deformation parameters
params.reg_deform_iterations="500x200x25x1"
params.reg_deform_auto_mask="0"

// parameter processing
fixed = file(params.fixed)
moving = file(params.moving)
outdir = file(params.reg_outdir)

affdir = file("${outdir}/aff")
if(!affdir.exists()) affdir.mkdirs()

tiledir = file("${outdir}/tiles")
if(!tiledir.exists()) tiledir.mkdirs()

aff_scale_subpath = "/${params.reg_chan}/${params.reg_aff_scale}"
def_scale_subpath = "/${params.reg_chan}/${params.reg_def_scale}"

ransac_affine = "${affdir}/ransac_affine"
transform_dir = "${outdir}/transform"
invtransform_dir = "${outdir}/invtransform"
warped_dir = "${outdir}/warped"

log.info """\
         BIGSTREAM REGISTRATION PIPELINE
         ===================================
         workDir         : $workDir
         outdir          : $outdir
         affdir          : $affdir
         tiledir         : $tiledir
         aff_scale       : $aff_scale_subpath
         def_scale       : $def_scale_subpath
         """
         .stripIndent()

include {
  cut_tiles;
  coarse_spots as coarse_spots_fixed;
  coarse_spots as coarse_spots_moving;
  ransac as coarse_ransac;
  apply_transform as apply_affine_small;
  apply_transform as apply_affine_big;
  spots as fixed_spots_for_tile;
  spots as moving_spots_for_tile;
  ransac as ransac_for_tile;
  interpolate_affines;
  deform;
  stitch;
  final_transform;
} from '../processes/registration.nf'

workflow {

    xy_overlap = params.reg_xy_stride / 8
    z_overlap = params.reg_z_stride / 8

    tiles = cut_tiles(fixed, def_scale_subpath, tiledir, \
        params.reg_xy_stride, xy_overlap, params.reg_z_stride, z_overlap) \
        | flatMap { it.tokenize(' ') }

    coarse_spots_fixed(fixed, aff_scale_subpath, \
        affdir, "/fixed_spots.pkl", params.reg_spots_cc_radius, params.reg_spots_spot_number)

    coarse_spots_moving(moving, aff_scale_subpath, \
        affdir, "/moving_spots.pkl", params.reg_spots_cc_radius, params.reg_spots_spot_number)

    joined_spots = coarse_spots_fixed.out.join(coarse_spots_moving.out)

    // compute transformation matrix (ransac_affine.mat)
    coarse_ransac_out = coarse_ransac(joined_spots, \
        "/ransac_affine.mat", \
        params.reg_ransac_cc_cutoff, params.reg_ransac_dist_threshold) | first

    // compute ransac_affine at aff scale
    apply_affine_small_out = apply_affine_small(1, \
        fixed, aff_scale_subpath, \
        moving, aff_scale_subpath, \
        coarse_ransac_out, ransac_affine)

    // compute ransac_affine at def scale
    apply_affine_big_out = apply_affine_big(8, \
        fixed, def_scale_subpath, \
        moving, def_scale_subpath, \
        coarse_ransac_out, ransac_affine)

    fixed_spots_for_tile([fixed, aff_scale_subpath], \
        tiles, "/fixed_spots.pkl", \
        params.reg_spots_cc_radius, params.reg_spots_spot_number)

    moving_spots_for_tile(apply_affine_small_out, \
        tiles, "/moving_spots.pkl", \
        params.reg_spots_cc_radius, params.reg_spots_spot_number)

    joined_spots_for_tile = fixed_spots_for_tile.out.join(moving_spots_for_tile.out)
    ransac_for_tile(joined_spots_for_tile, \
        "/ransac_affine.mat", \
        params.reg_ransac_cc_cutoff, params.reg_ransac_dist_threshold)

    interpolate_affines_out = interpolate_affines(ransac_for_tile.out.collect(), tiledir)

    deform(interpolate_affines_out, tiles, fixed, def_scale_subpath, \
        apply_affine_big_out, params.reg_deform_iterations, params.reg_deform_auto_mask)

    stitch(deform.out.collect(), \
         tiles, xy_overlap, z_overlap, fixed, def_scale_subpath, coarse_ransac_out, \
         transform_dir, invtransform_dir, "/${params.def_scale}")

    final_transform(stitch.out.collect(), \
        fixed, def_scale_subpath, \
        moving, def_scale_subpath, \
        transform_dir, warped_dir)
}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
