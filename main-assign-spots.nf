#!/usr/bin/env nextflow
/*
    Assign spots
*/
nextflow.enable.dsl=2

// path to the labels image
params.labels = ""

// path to the warped spots files
params.warped_spots = ""

// path to the folder where you'd like all outputs to be written
params.outdir = ""

include {
    default_mf_params;
    spots_assignment_container_param;
} from './param_utils'

final_params = default_mf_params() + params

include {
    assign_spots;
} from './processes/spot_assignment' addParams(spots_assignment_container: spots_assignment_container_param(final_params),
                                               assign_spots_cpus: final_params.assign_spots_cpus)

workflow {

    outdir = file(final_params.outdir)
    outdir.mkdirs()

    warped_spots_files = Channel.fromPath("${final_params.warped_spots}/*.txt")

    assigned_spots_inputs = warped_spots_files.map { f -> 
        def fname = f.name.replaceAll(".txt","-assigned")
        [
            final_params.labels,
            f,
            "${outdir}/${fname}"
        ]
    }

    assign_spots(
        assigned_spots_inputs.map { it[0] },
        assigned_spots_inputs.map { it[1] },
        assigned_spots_inputs.map { it[2] },
        final_params.assign_spots_cpus
    )

}
