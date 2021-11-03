
include { airlocalize } from './airlocalize'
include { rsfish } from './rs_fish'

workflow spot_extraction {
    take:
    input_images
    spot_extraction_output_dirs
    spot_channels
    bleedthrough_channels

    main:

    spot_extraction_results = Channel.of([])

    if (params.run_airlocalize) {
        def airlocalize_results = airlocalize(
            input_images,
            spot_extraction_output_dirs,
            spot_channels,
            params.spot_extraction_scale,
            params.dapi_channel,
            bleedthrough_channels
        ) // [ input_image, ch, scale, spots_file ]
        airlocalize_results.subscribe { log.debug "Airlocalize results: $it" }
        spot_extraction_results = spot_extraction_results.concat(airlocalize_results)
    }
    
    if (params.run_rsfish) {
        def rsfish_results = rsfish(
            input_images,
            spot_extraction_output_dirs,
            spot_channels,
            params.spot_extraction_scale,
            params.dapi_channel,
            bleedthrough_channels
        ) // [ input_image, ch, scale, spots_file ]
        rsfish_results.subscribe { log.debug "RS-FISH results: $it" }
        spot_extraction_results = spot_extraction_results.concat(rsfish_results)
    }

    emit:
    spot_extraction_results
}