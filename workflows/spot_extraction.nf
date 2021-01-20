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
    | combine(spot_extraction_inputs) \
    | map { it[1] } \
    | set { done }

    emit:
    done
}
