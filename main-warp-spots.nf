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
    default_mf_params;
    registration_container_param;
} from './param_utils'

final_params = default_mf_params() + params
registration_params = final_params + [
    registration_container: registration_container_param(final_params),
]

include {
    warp_spots;
} from './workflows/warp_spots' addParams(registration_params)

workflow {

    outdir = file(final_params.warped_spots_outdir)
    outdir.mkdirs()

    points_files = Channel.fromPath(final_params.points_dir+"/*.txt")
    output_filenames = points_files.map { f -> 
        def fname = f.name.replaceAll(".txt","-warped.txt")
        return "${outdir}/${fname}"
    }

    // parameter processing

    warp_spots(final_params.fixed,
               final_params.fixed_subpath,
               final_params.moving,
               final_params.moving_subpath,
               final_params.warped_spots_txmpath,
               points_files,
               output_filenames
    )

}
