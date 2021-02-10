process quantify_spots {
    container = params.spots_assignment_container
    cpus { cpus }

    input:
    val(labels_path)
    val(registered_image_path)
    val(result_name)
    val(ch)
    val(scale)
    val(output_path)
    val(dapi_channel)
    val(bleed_channel)
    val(cpus)

    output:
    tuple val(spots_path), val(output_path)

    script:
    args_list = [
        labels_path,
        registered_image_path,
        output_path,
        result_name,
        ch,
        scale,
        dapi_channel,
        bleed_channel

    ]
    args = args_list.join(' ')
    """
    echo "python /app/intensity_measurement/scripts/intensity_measurements.py ${args}"
    python /app/intensity_measurement/scripts/intensity_measurements.py ${args}
    """
}