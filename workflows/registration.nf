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
  cut_tiles;
  coarse_spots as coarse_spots_fixed;
  coarse_spots as coarse_spots_moving;
  ransac as coarse_ransac;
  apply_transform as apply_affine_small;
  apply_transform as apply_affine_big;
  spots as spots_fixed;
  spots as spots_moving;
  ransac as ransac_for_tile;
  interpolate_affines;
  deform;
  stitch;
  final_transform;
} from '../processes/registration.nf'


workflow spots_for_tile {
    take:
        tile
        ransac_affine_mat
        affine_small // tuple ransac_affine, subpath
    main:
        tile_fixed_spots = spots_fixed(fixed, aff_scale_subpath, \
            tile, "fixed_spots.pkl", params.spots_cc_radius, params.spots_spot_number)

        // extract the tuple parts
        affine_small_path = affine_small.map { t -> t[0] }
        affine_small_subpath = affine_small.map { t -> t[1] }

        tile_moving_spots = spots_moving(affine_small_path, affine_small_subpath, \
            tile, "moving_spots.pkl", params.spots_cc_radius, params.spots_spot_number)

        tile_ransac = ransac_for_tile(tile_fixed_spots, tile_moving_spots, \
            tile, "ransac_affine.mat", params.ransac_cc_cutoff, params.ransac_dist_threshold)
    emit:
        tile_ransac
}


workflow {

    xy_overlap = params.xy_stride / 8
    z_overlap = params.z_stride / 8

    tiles = cut_tiles(fixed, def_scale_subpath, tiledir, \
        params.xy_stride, xy_overlap, params.z_stride, z_overlap) \
        | flatMap { it.tokenize(' ') }

    fixed_spots = coarse_spots_fixed(fixed, aff_scale_subpath, \
        "${affdir}/fixed_spots.pkl", params.spots_cc_radius, params.spots_spot_number)

    moving_spots = coarse_spots_moving(moving, aff_scale_subpath, \
        "${affdir}/moving_spots.pkl", params.spots_cc_radius, params.spots_spot_number)

    // compute transformation matrix (ransac_affine.mat)
    ransac_affine_mat = coarse_ransac(fixed_spots, moving_spots, \
        affdir, "ransac_affine.mat", \
        params.ransac_cc_cutoff, params.ransac_dist_threshold)

    // compute ransac_affine at aff scale
    affine_small = apply_affine_small(1, \
        fixed, aff_scale_subpath, \
        moving, aff_scale_subpath, \
        ransac_affine_mat, "${affdir}/ransac_affine", "")

    // ransac_affine at def scale
    affine_big = apply_affine_big(8, \
        fixed, def_scale_subpath, \
        moving, def_scale_subpath, \
        ransac_affine_mat, "${affdir}/ransac_affine", "")

    spot_output = spots_for_tile(tiles, ransac_affine_mat, affine_small)
    interpolation = interpolate_affines(spot_output.collect(), tiledir)

    deform_output = deform(interpolation, tiles, fixed, def_scale_subpath, affine_big, \
        params.deform_iterations, params.deform_auto_mask)

    stitch_output = stitch(deform_output.collect(), \
         tiles, xy_overlap, z_overlap, fixed, def_scale_subpath, ransac_affine_mat, \
         transform_dir, invtransform_dir, "/${params.def_scale}")

    final_transform(stitch_output.collect(), \
        fixed, def_scale_subpath, \
        moving, def_scale_subpath, \
        transform_dir, warped_dir)

}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

