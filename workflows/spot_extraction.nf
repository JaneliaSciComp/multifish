include {
    cut_tiles;
    airlocalize;
    merge_points;
} from '../processes/spot_extraction' addParams(lsf_opts: params.lsf_opts, 
                                                spotextraction_container: params.spotextraction_container)

include {
    index_channel;
} from '../utils/utils'

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
    tile_cut_res = cut_tiles(
        input_dir,
        channels[0],
        scale,
        output_dir,
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ) |  flatMap { it.tokenize(' ') }

    indexed_tile_cut_input = index_channel(tile_cut_res[0])
    indexed_tiles = indexed_tile_cut_input | join(index_channel(tile_cut_res[1])) | flatMap {
        def tile_input = it[1]
        def tile_dirs = it[2].tokenize(' ').collect {
            [ tile_input, it ]
        }
    }

    airlocalize_inputs = tile_dirs | combine(channels) | map {
        def tile_dir = it[0]
        def ch = it[1]
        def dapi_correction = dapi_correction_channels.contains(ch)
                ? "/${args.dapi_channel}/${args.scale}"
                : ''
        // return a tuple with all required arguments for airlocalize
        def airlocalize_args = [
            input_dir,
            ch,
            scale,
            "${tile_dir}/coords.txt",
            per_channel_air_localize_params[ch],
            tile_dir,
            "_${ch}.txt",
            dapi_correction
        ]
        println "Create airlocalize args: ${airlocalize_args}"
        return airlocalize_args
    }

    airlocalize_results = airlocalize(
        airlocalize_inputs.map { it[0] },
        airlocalize_inputs.map { it[1] },
        airlocalize_inputs.map { it[2] },
        airlocalize_inputs.map { it[3] },
        airlocalize_inputs.map { it[4] },
        airlocalize_inputs.map { it[5] },
        airlocalize_inputs.map { it[6] },
        airlocalize_inputs.map { it[7] }
    )

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
