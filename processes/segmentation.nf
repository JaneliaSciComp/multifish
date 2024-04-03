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
    tuple val(image_path), env(output_fullpath)

    script:
    def output_file = file(output_path)
    def output_dir = output_file.parent
    def output_name = output_file.name
    """
    model_fullpath=\$(readlink ${model_path})
    output_fulldir=\$(readlink ${output_dir})
    mkdir -p \${output_fulldir}
    output_fullpath="\${output_fulldir}/${output_name}"
    echo "python /app/segmentation/scripts/starfinity_prediction.py \
            -i ${image_path} \
            -c ${ch} \
            -s ${scale} \
            -o ${output_path} \
            -m \${model_fullpath} \
            "
    python /app/segmentation/scripts/starfinity_prediction.py \
        -i ${image_path} \
        -c ${ch} \
        -s ${scale} \
        -o ${output_path} \
        -m \${model_fullpath}
    """
}
