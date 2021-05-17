process predict {
    //label 'withGPU'

    container { params.segmentation_container }
    cpus { params.segmentation_cpus }
    memory { params.segmentation_memory }

    input:
    val(image_path)
    val(ch)
    val(scale)
    val(model_path)
    val(output_path)

    output:
    tuple val(image_path), val(output_path)

    script:
    def output_file = file(output_path)
    args_list = [
        '-i', image_path,
        '-m', model_path,
        '-c', ch,
        '-s', scale,
        '-o', output_path
    ]
    args = args_list.join(' ')
    """
    mkdir -p ${output_file.parent}
    echo "python /app/segmentation/scripts/starfinity_prediction.py ${args}"
    python /app/segmentation/scripts/starfinity_prediction.py ${args}
    """
}
