#!/usr/bin/env nextflow

/*
    Registration using Bigstream
    Parameters:
        fixed
        moving
        outdir
*/
nextflow.enable.dsl=2

// the fixed n5 image
params.fixed = ""

// the moving n5 image
params.moving = ""

// the folder where you'd like all outputs to be written
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
params.auto_mask="0"

// Bring some params into global scope
fixed = file(params.fixed)
moving = file(params.moving)
outdir = file(params.outdir)

affdir = file("${outdir}/aff")
if(!affdir.exists()) affdir.mkdirs()

tiledir = file("${outdir}/tiles")
if(!tiledir.exists()) tiledir.mkdirs()

log.info """\
         BIGSTREAM PIPELINE
         ===================================
         workDir         : ${workDir}
         outdir          : ${params.outdir}
         affdir          : ${affdir}
         tiledir         : ${tiledir}
         """
         .stripIndent()

include {
  cut_tiles;
  coarse_spots as coarse_spots_fixed;
  coarse_spots as coarse_spots_moving;
  coarse_ransac;
  apply_transform as apply_affine_small;
  apply_transform as apply_affine_big;
  spots as spots_fixed;
  spots as spots_moving;
} from './registration_process.nf'


workflow spots_for_tile {
    take:
        tile
        fixed_spots
        moving_spots
        affine_small // tuple ransac_affine, subpath
    main:
        tile_fixed_spots = spots_fixed(tile, fixed, "/${params.channel}/${params.aff_scale}", \
            fixed_spots, params.spots_cc_radius, params.spots_spot_number)

        ransac_affine = affine_small.map { t -> t[0] }
        subpath = affine_small.map { t -> t[1] }

        tile_moving_spots = spots_moving(tile, ransac_affine, subpath, \
            moving_spots, params.spots_cc_radius, params.spots_spot_number)

    emit:
        tile_moving_spots
}


workflow {

    xy_overlap = params.xy_stride / 8
    z_overlap = params.z_stride / 8

    coords = cut_tiles(fixed, "/${params.channel}/${params.def_scale}", tiledir, \
        params.xy_stride, xy_overlap, params.z_stride, z_overlap)

    fixed_spots = coarse_spots_fixed(fixed, "/${params.channel}/${params.aff_scale}", \
        "${affdir}/fixed_spots.pkl", params.spots_cc_radius, params.spots_spot_number)

    moving_spots = coarse_spots_moving(moving, "/${params.channel}/${params.aff_scale}", \
        "${affdir}/moving_spots.pkl", params.spots_cc_radius, params.spots_spot_number)

    ransac_affine = coarse_ransac(fixed_spots, moving_spots, "${affdir}/ransac_affine.mat", \
        params.ransac_cc_cutoff, params.ransac_dist_threshold)

    affine_small = apply_affine_small(1, fixed, "/${params.channel}/${params.aff_scale}", \
        moving, "/${params.channel}/${params.aff_scale}", \
        ransac_affine, "${affdir}/ransac_affine", "")

    affine_big = apply_affine_big(8, fixed, "/${params.channel}/${params.def_scale}", \
        moving, "/${params.channel}/${params.def_scale}", \
        ransac_affine, "${affdir}/ransac_affine", "")

    tiles = Channel.fromPath("${tiledir}/*", type: 'dir')
    //tiles.subscribe {  println "Got: $it"  }
    ransacs = spots_for_tile(tiles, fixed_spots, moving_spots, affine_small)

}
