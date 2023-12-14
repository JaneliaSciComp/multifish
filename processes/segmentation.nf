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
    """
    model_fullpath=\$(readlink ${model_path})
    mkdir -p ${output_file.parent}
    echo "python /app/segmentation/scripts/starfinity_prediction.py \
            -i ${image_path} \
            -c ${ch} \
            -s ${scale} \
            -o ${output_path} \
            -m \${model_fullpath} \
            --tile-size ${params.segmentation_tile_size}"
    python /app/segmentation/scripts/starfinity_prediction.py \
        -i ${image_path} \
        -c ${ch} \
        -s ${scale} \
        -o ${output_path} \
        -m \${model_fullpath} \
        --tile-size ${params.segmentation_tile_size}
    """
}
