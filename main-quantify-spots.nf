#!/usr/bin/env nextflow
/*
    Quantify spots
*/
nextflow.enable.dsl=2

// path to the labels image
params.labels = ""

// path to the warped spots files
params.warped_spots = ""

// path to the warped image
params.warped_image = ""

// prefix name for the intensities file
params.prefix = 'R'

// path to the folder where you'd like all outputs to be written
params.outdir = ""

include {
    default_mf_params;
    spots_assignment_container_param;
} from './param_utils'

final_params = default_mf_params() + params

include {
    quantify_spots;
} from './processes/quantification' addParams(spots_assignment_container: spots_assignment_container_param(final_params),
                                              intensity_cpus: final_params.intensity_cpus)

workflow {

    outdir = file(final_params.outdir)
    outdir.mkdirs()

    warped_spots_files = Channel.fromPath("${final_params.warped_spots}/*.txt")

    quantify_spots_inputs = warped_spots_files | map { f -> 
        def fname = f.name.replaceAll('.txt', '')
        def ch_lookup = (fname =~ /[-_](c\d+)[-_]/)
        def ch
        if (ch_lookup.find()) {
            ch = ch_lookup[0][1]
        } else {
            ch = ''
        }
        [
            final_params.labels,
            final_params.warped_image,
            final_params.prefix,
            ch,
            final_params.deform_scale,
            outdir
        ]
    } | filter { it[3] != '' } // channel must be present in the warped spots file name

    quantify_spots(
        quantify_spots_inputs.map { it[0] }, // labels
        quantify_spots_inputs.map { it[1] }, // warped image
        quantify_spots_inputs.map { it[2] }, // prefix (round name)
        quantify_spots_inputs.map { it[3] }, // channel
        quantify_spots_inputs.map { it[4] }, // scale
        quantify_spots_inputs.map { it[5] }, // output dir
        final_params.dapi_channel, // dapi_channel
        final_params.bleed_channel, // bleed_channel
        final_params.intensity_cpus, // cpus
    )

}
