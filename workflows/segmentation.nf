include {
    predict;
} from '..'

workflow segmentation {
    take:
    segmentation_inputs

    main:
    
    per_channel_segmentation_inputs = segmentation_inputs \
    | flatMap { args ->
        args.channels.collect { ch ->
            [
                args + [ch: ch]
            ]
        }
    }


    segmentation_inputs \
    | map { args ->
        [
            args.data_dir,
            args.dapi_channel,
            args.scale,
            args.model_dir,
            args.segmentation_output_dir
        ]
    }


}