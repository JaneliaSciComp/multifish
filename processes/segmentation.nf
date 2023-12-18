process predict {
    label 'withGPU'

    container { params.segmentation_container }
    cpus { params.segmentation_cpus }
    memory { params.segmentation_memory }

    input:
    val(image_path)
    val(ch)
    val(scale)
    path(model_path)
    val(output_path)

    output:
    tuple val(image_path), val(output_path)

    script:
    def output_file = file(output_path)
    def affinity_threshold_arg = params.stardist_affinity_thresh
        ? "--affinity-thresh ${params.stardist_affinity_thresh}"
        : ''
    def probability_threshold_arg = params.stardist_prob_thresh
        ? "--prob-thresh ${params.stardist_prob_thresh}"
        : ''
    def nms_threshold_arg = params.stardist_nms_thresh
        ? "--nms-thresh ${params.stardist_nms_thresh}"
        : ''
    """
    model_fullpath=\$(readlink ${model_path})
    mkdir -p ${output_file.parent}
    echo "python /app/segmentation/scripts/starfinity_prediction.py \
            -i ${image_path} \
            -c ${ch} \
            -s ${scale} \
            -o ${output_path} \
            -m \${model_fullpath} \
            --tile-size ${params.stardist_tile_size} \
            ${affinity_threshold_arg} \
            ${probability_threshold_arg} 
            ${nms_threshold_arg} \
            "
    python /app/segmentation/scripts/starfinity_prediction.py \
        -i ${image_path} \
        -c ${ch} \
        -s ${scale} \
        -o ${output_path} \
        -m \${model_fullpath} \
        --tile-size ${params.stardist_tile_size} \
        ${affinity_threshold_arg} \
        ${probability_threshold_arg} \
        ${nms_threshold_arg}
    """
}
