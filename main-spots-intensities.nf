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
    measure_intensities;
} from './processes/spot_intensities' addParams(spots_assignment_container: spots_assignment_container_param(final_params),
                                                measure_intensities_cpus: final_params.measure_intensities_cpus)

workflow {

    outdir = file(final_params.outdir)
    outdir.mkdirs()

    if (!final_params.warped_image) {
        log.error "Warped spots image must be specified"
    }

    if (!final_params.warped_spots) {
        log.error "Directory containing warped points files must be specified"
    }

    warped_spots_files = Channel.fromPath("${final_params.warped_spots}/*.txt")

    intensities_spots_inputs = warped_spots_files | map { f ->
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
            final_params.def_scale,
            outdir
        ]
    } | filter { it[3] != '' } // channel must be present in the warped spots file name

    measure_intensities(
        intensities_spots_inputs.map { it[0] }, // labels
        intensities_spots_inputs.map { it[1] }, // warped image
        intensities_spots_inputs.map { it[2] }, // prefix (round name)
        intensities_spots_inputs.map { it[3] }, // channel
        intensities_spots_inputs.map { it[4] }, // scale
        intensities_spots_inputs.map { it[5] }, // output dir
        final_params.dapi_channel, // dapi_channel
        final_params.bleed_channel, // bleed_channel
        final_params.measure_intensities_cpus, // cpus
    )

}
