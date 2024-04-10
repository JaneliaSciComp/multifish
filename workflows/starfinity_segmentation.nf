include {
    index_channel;
} from './utils'

include {
    predict;
} from '../processes/segmentation'  addParams(lsf_opts: params.lsf_opts,
                                              segmentation_container: params.segmentation_container)

workflow SEGMENTATION {
    take:
    input_dirs
    acqs
    output_dirs
    dapi_channel
    scale
    model_dir

    main:
    def indexed_acqs = index_channel(acqs)
    def output_files = indexed_acqs | join(index_channel(output_dirs)) | map {
        // <output_dir>/<acq>-<dapi-ch>.tif
        [
            file(it[2]),
            "${it[1]}-${scale}-${dapi_channel}.tif",
        ]
    }

    segmentation_results = predict(
        input_dirs,
        dapi_channel,
        scale,
        file(model_dir),
        output_files
    )

    segmentation_results.subscribe { log.debug "Segmentation results: $it" }

    emit:
    segmentation_results // [ input_image_path, output_labels_tiff ]
}
