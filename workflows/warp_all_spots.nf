#!/usr/bin/env nextflow
/*
    Warp all spots to registration
*/
nextflow.enable.dsl=2

// path to the fixed n5 image
params.fixed = ""

// path to the moving n5 image
params.moving = ""

// the channel used to drive registration
params.fixed_subpath = "/c2/s2"

// the scale level for affine alignments
params.moving_subpath = "/c2/s2"

// inverse transform matrix to use for warping the spots
params.warped_spots_txmpath = ""

// extracted spot dir
params.points_dir = ""

// path to the folder where you'd like all outputs to be written
params.warped_spots_outdir = ""

include {
    warp_spots;
} from '../workflows/warp_spots' 

workflow {

    points_files = Channel.fromPath(params.points_dir+"/*.txt")
    output_filenames = points_files.map { f -> f.name.replaceAll(".txt","-warped.txt") }

    // parameter processing
    fixed = file(params.fixed)
    moving = file(params.moving)
    outdir = file(params.warped_spots_outdir)

    warp_spots( \
        fixed, params.fixed_subpath, moving, params.moving_subpath, \
        params.warped_spots_txmpath, outdir, output_filenames, points_files)

}
