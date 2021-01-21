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
    | flatMap {
        println "Cut tiles results: $it"
        it.tokenize(' ')
    }
    | combine(spot_extraction_inputs) \
    | flatMap {
        tile_dir = it[0]
        args = it[1]
        println "Prepare airlocalize parameters for tile ${tile_dir}: ${args}"
        args.channels.collect { ch ->
            dapi_correction = args.dapi_correction_channels.contains(ch)
                ? "/${args.dapi_channel}/${args.scale}"
                : ''
            [
                args.data_dir,
                ch,
                args.scale,
                "${tile_dir}/coords.txt",
                args.per_channel_air_localize_params[ch],
                tile_dir,
                "_${current_ch}.txt",
                dapi_correction
            ]
        }
    } \
    | set { done }

    emit:
    done
}
