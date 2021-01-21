include {
    cut_tiles;
    airlocalize;
} from '../processes/spot_extraction' addParams(lsf_opts: params.lsf_opts, 
                                                mfrepo: params.mfrepo)

workflow spot_extraction {
    take:
    spot_extraction_inputs

    main:
    spot_extraction_inputs \
    | map { args ->
        println "Create args for cutting tiles using only ${args.channels[0]} from ${args}"
        cut_tiles_args = [
            args.data_dir,
            args.channels[0],
            args.scale,
            args.spot_extraction_output_dir,
            args.xy_stride,
            args.xy_overlap,
            args.z_stride,
            args.z_overlap
        ]
        println "Cut tile args: ${cut_tiles_args}"
        return cut_tiles_args
    } \
    | cut_tiles \
    | map {
        println "!!!! CUT TILES RES: $it"
        it
    }

    // spot_extraction_inputs \
    // | map 
    // | map {
    //     // extract the channel only from the result
    //     it[1]
    // } \
    // | combine(spot_extraction_inputs) \
    // | flatMap {
    //     current_ch = it[0]
    //     args = it[1]
    //     println "Prepare airlocalize parameters for "
    //     dapi_correction = args.dapi_correction_channels.contains(current_ch)
    //         ? "/${args.dapi_channel}/${args.scale}"
    //         : ''
    //     Channel.fromPath("${args.spot_extraction_output_dir}/*[0-9]")
    //         .map {
    //             [
    //                 args.data_dir,
    //                 current_ch,
    //                 args.scale,
    //                 "${it}/coords.txt",
    //                 args.per_channel_air_localize_params[current_ch],
    //                 it,
    //                 "_${current_ch}.txt",
    //                 dapi_correction
    //             ]
    //         }
    // } \
    // | set { done }

    emit:
    done
}
