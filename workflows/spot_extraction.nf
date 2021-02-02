include {
    cut_tiles;
    airlocalize;
    merge_points;
} from '../processes/spot_extraction' addParams(lsf_opts: params.lsf_opts, 
                                                spotextraction_container: params.spotextraction_container)

workflow spot_extraction {
    take:
    input_dir
    output_dir
    channels
    scale
    xy_stride
    xy_overlap
    z_stride
    z_overlap
    dapi_channel
    dapi_correction_channels
    per_channel_air_localize_params

    main:
    tile_dirs = cut_tiles(
        input_dir,
        channels[0],
        scale,
        output_dir,
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ) |  flatMap { it.tokenize(' ') }

    airlocalize_args = tile_dirs | combine(channels) | map {
        tile_dir = it[0]
        ch = it[1]
        dapi_correction = dapi_correction_channels.contains(ch)
                ? "/${args.dapi_channel}/${args.scale}"
                : ''
        return [
            tile_dir,
            ch,
            scale,
            "${tile_dir}/coords.txt",
            per_channel_air_localize_params[ch],
            tile_dir,
            "_${ch}.txt",
            dapi_correction
        ]
    }



    // per_channel_spot_extraction_inputs = spot_extraction_inputs \
    // | flatMap { args ->
    //     args.channels.collect { ch ->
    //         [
    //             ch,
    //             args
    //         ]
    //     }
    // }



    // | flatMap {
    //     println "Cut tiles results: $it"
    //     it.tokenize(' ')
    // } \
    // | combine(spot_extraction_inputs) \
    // | flatMap {
    //     tile_dir = it[0]
    //     args = it[1]
    //     println "Prepare airlocalize parameters for tile ${tile_dir}: ${args}"
    //     args.channels.collect { ch ->
    //         dapi_correction = args.dapi_correction_channels.contains(ch)
    //             ? "/${args.dapi_channel}/${args.scale}"
    //             : ''
    //         println "DAPI correction for channel ${ch}: ${dapi_correction}"
    //         airlocalize_args_per_tile_and_ch = [
    //             args.data_dir,
    //             ch,
    //             args.scale,
    //             "${tile_dir}/coords.txt",
    //             args.per_channel_air_localize_params[ch],
    //             tile_dir,
    //             "_${ch}.txt",
    //             dapi_correction
    //         ]
    //         println "Airlocalize args for tile ${tile_dir} channel ${ch}: ${airlocalize_args_per_tile_and_ch}"
    //         airlocalize_args_per_tile_and_ch
    //     }
    // } \
    // | airlocalize \
    // | groupTuple \
    // | join(per_channel_spot_extraction_inputs) \
    // | map {
    //     ch = it[0]
    //     args = it[2]
    //     merge_points_args = [
    //         args.data_dir,
    //         ch,
    //         args.scale,
    //         args.spot_extraction_output_dir,
    //         args.xy_overlap,
    //         args.z_overlap,
    //         args.spot_extraction_output_dir
    //     ]
    //     println "Prepare merge points args: ${merge_points_args}"
    //     return merge_points_args
    // } \
    // | merge_points \
    // | set { done }

    emit:
    done
}
