#!/usr/bin/env nextflow
/*
    Extract spots
*/
nextflow.enable.dsl=2

// path to the n5 stitched acquisition
params.stitchdir = ""

// path to the folder where you'd like all outputs to be written
params.outdir = ""

include {
    default_mf_params;
    airlocalize_container_param;
    airlocalize_xy_stride_param;
    airlocalize_xy_overlap_param;
    airlocalize_z_stride_param;
    airlocalize_z_overlap_param;
} from './param_utils'

final_params = default_mf_params() + params

airlocalize_params = final_params + [
    airlocalize_container: airlocalize_container_param(final_params),
    airlocalize_xy_stride: airlocalize_xy_stride_param(final_params),
    airlocalize_xy_overlap: airlocalize_xy_overlap_param(final_params),
    airlocalize_z_stride: airlocalize_z_stride_param(final_params),
    airlocalize_z_overlap: airlocalize_z_overlap_param(final_params),
]
include {
    spot_extraction;
} from './workflows/spot_extraction' addParams(airlocalize_params)

channels = final_params.channels?.split(',')
bleedthrough_channels = final_params.bleed_channel?.split(',')

workflow {

    outdir = file(final_params.outdir)
    outdir.mkdirs()

    if (!final_params.stitchdir) {
        log.error "Stitched image must be specified"
    }

    spot_extraction(
        final_params.stitchdir,
        Channel.of(outdir),
        channels,
        bleedthrough_channels // bleed_channel
    )

}
