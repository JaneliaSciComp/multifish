include {
    predict;
} from '../processes/segmentation'  addParams(lsf_opts: params.lsf_opts,
                                              mfrepo: params.mfrepo)

workflow segmentation {
    take:
    segmentation_inputs

    main:

    segmentation_inputs \
    | map { args ->
        [
            args.data_dir,
            args.dapi_channel,
            args.scale,
            args.model_dir,
            args.segmentation_output_dir
        ]
    } \
    | predict \
    | set { done }

    emit:
    done
}
