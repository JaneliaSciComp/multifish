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
    tuple path(output_dir), val(output_name)

    output:
    tuple val(image_path), env(output_fullpath)

    script:
    """
    model_fullpath=\$(readlink ${model_path})
    output_fulldir=\$(readlink ${output_dir})
    mkdir -p \${output_fulldir}
    output_fullpath="\${output_fulldir}/${output_name}"
    echo "Run starfinity model \${model_fullpath} -> \${output_fullpath}"
    echo "python /app/segmentation/scripts/starfinity_prediction.py \
            -i ${image_path} \
            -c ${ch} \
            -s ${scale} \
            -o \${output_fullpath} \
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
