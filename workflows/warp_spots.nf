#!/usr/bin/env nextflow
/*
    Warp spots to registration
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

// extracted spots
params.points_path = ""

// inverse transform matrix to use for warping the spots
params.warped_spots_txmpath = ""

// path to the folder where you'd like all outputs to be written
params.warped_spots_outdir = ""

// name of the output file in the outdir
params.warped_spots_outfile = "warped_spots.txt"


process warp_spots_transform {
    container = params.registration_container
    cpus "6"

    input:
    val ref_img_path
    val ref_img_subpath
    val mov_img_path
    val mov_img_subpath
    val txm_path
    val output_path
    val points_path

    output:
    tuple val(output_path), val(ref_img_subpath)

    script:
    """
    /app/scripts/waitforpaths.sh ${ref_img_path}${ref_img_subpath} ${mov_img_path}${mov_img_subpath} $txm_path
    /entrypoint.sh apply_transform_n5 $ref_img_path $ref_img_subpath $mov_img_path $mov_img_subpath $txm_path $output_path $points_path
    """
}

workflow warp_spots {

    take:
        fixed
        fixed_subpath
        moving
        moving_subpath
        warped_spots_txmpath
        warped_spots_outdir
        warped_spots_outfile
        points_path

    main:
        warped_spots_out = "${warped_spots_outdir}/${warped_spots_outfile}"
        
        log.info """\
                WARP SPOTS
                ===================================
                workDir              : $workDir
                warped_spots_txmpath : $warped_spots_txmpath
                warped_spots_outdir  : $warped_spots_outdir
                warped_spots_outfile : $warped_spots_outfile
                """
                .stripIndent()
                
        if(!warped_spots_outdir.exists()) warped_spots_outdir.mkdirs()

        warp_spots_transform( \
            fixed, fixed_subpath, moving, moving_subpath, \
            warped_spots_txmpath, warped_spots_out, points_path)
}

workflow {

    // parameter processing
    fixed = file(params.fixed)
    moving = file(params.moving)
    outdir = file(params.warped_spots_outdir)

    warp_spots( \
        fixed, params.fixed_subpath, moving, params.moving_subpath, \
        params.warped_spots_txmpath, outdir, params.warped_spots_outfile, params.points_path)

}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
