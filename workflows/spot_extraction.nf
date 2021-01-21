include {
    cut_tiles;
} from '../processes/spot_extraction' addParams(lsf_opts: params.lsf_opts, 
                                                mfrepo: params.mfrepo)

workflow spot_extraction {
    take:
    spot_extraction_inputs

    main:
    spot_extraction_inputs \
    | flatMap { args ->
        println "Create per channel parameters for spot extraction: ${args}"
        args.channels.collect { ch ->
            ch_args = [
                args.data_dir,
                ch,
                args.scale,
                args.spot_extraction_output_dir,
                args.xy_stride,
                args.xy_overlap,
                args.z_stride,
                args.z_overlap
            ]
            println "Cut args for ch: ${ch} -> ${ch_args}"
            return ch_args
        }
    } \
    | cut_tiles \
    | map {
        // extract the channel only from the result
        it[1]
    } \
    | combine(spot_extraction_inputs) \
    | flatMap {
        current_ch = it[0]
        args = it[1]
        dapi_correction = args.dapi_correction_channels.contains(current_ch)
            ? "/${args.dapi_channel}/${args.scale}"
            : ''
        Channel.fromPath("${args.spot_extraction_output_dir}/*[0-9]")
            .map {
                [
                    args.data_dir,
                    current_ch,
                    args.scale,
                    "${it}/coords.txt",
                    args.per_channel_air_localize_params[current_ch],
                    it,
                    "_${current_ch}.txt",
                    dapi_correction
                ]
            }
    } \
    | set { done }

    emit:
    done
}
