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
    spotextraction_container_param;
} from './param_utils'

final_params = default_mf_params() + params

include {
    spot_extraction;
} from './workflows/spot_extraction' addParams(lsf_opts: final_params.lsf_opts,
                                               spotextraction_container: spotextraction_container_param(final_params),
                                               spot_extraction_cpus: final_params.spot_extraction_cpus,
                                               spot_extraction_memory: final_params.spot_extraction_memory)

channels = final_params.channels?.split(',')
spot_extraction_dapi_correction_channels = final_params.spot_extraction_dapi_correction_channels?.split(',')
per_channel_air_localize_params = [
    channels,
    final_params.per_channel_air_localize_params?.split(',', -1)
].transpose()
 .inject([:]) { a, b ->
    ch = b[0]
    airlocalize_params = b[1] == null || b[1] == ''
        ? final_params.default_airlocalize_params
        : b[1]
    a[ch] =  airlocalize_params
    return a 
}

workflow {

    outdir = file(final_params.outdir)
    outdir.mkdirs()

    if (!final_params.stitchdir) {
        log.error "Stitched image must be specified"
    }

    spot_extraction(
        final_params.stitchdir,
        outdir,
        channels,
        final_params.scale_4_spot_extraction,
        spot_extraction_xy_stride_param(final_params),
        spot_extraction_xy_overlap_param(final_params),
        spot_extraction_z_stride_param(final_params),
        spot_extraction_z_overlap_param(final_params),
        final_params.dapi_channel,
        spot_extraction_dapi_correction_channels,
        per_channel_air_localize_params
    )

}
