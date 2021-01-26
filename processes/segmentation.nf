process predict {
    label "withGPU"

    container = "${params.mfrepo}/segmentation:1.0"

    input:
    tuple val(image_path),
          val(ch),
          val(scale),
          val(model_path),
          val(output_path)

    output:
    val(output_path)

    script:
    args_list = [
        '-i', image_path,
        '-m', model_path,
        '-c', ch,
        '-s', scale,
        '-o', output_path
    ]
    args = args_list.join(' ')
    """
    echo "python /app/segmentation/scripts/starfinity_prediction.py ${args}"
    python /app/segmentation/scripts/starfinity_prediction.py ${args}
    """
}
