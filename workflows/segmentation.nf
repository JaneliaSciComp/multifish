include {
    SEGMENTATION as CELLPOSE_SEGMENTATION;
} from './cellpose_segmentation'

include {
    SEGMENTATION as STARFINITY_SEGMENTATION;
} from './starfinity_segmentation'

workflow segmentation {
    take:
    input_dirs
    acqs
    output_dirs
    dapi_channel
    scale
    model_dir

    main:
    if (params.use_cellpose) {
        done = CELLPOSE_SEGMENTATION(
            input_dirs,
            acqs,
            output_dirs,
            dapi_channel,
            scale,
        )
    } else {
        done = STARFINITY_SEGMENTATION(
            input_dirs,
            acqs,
            output_dirs,
            dapi_channel,
            scale,
            model_dir,
        )
    }

    emit:
    done
}
