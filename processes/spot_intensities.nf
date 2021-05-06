process measure_intensities {
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
    tuple val(labels_path), val(registered_image_path), val(ch), val(output_path)

    script:
    def args_list = [
        labels_path,
        registered_image_path,
        output_path,
        result_name,
        ch,
        scale,
        dapi_channel,
        bleed_channel

    ]
    def args = args_list.join(' ')
    """
    umask 0002
    mkdir -p ${output_path}
    echo "python /app/intensity_measurement/scripts/intensity_measurements.py ${args}"
    python /app/intensity_measurement/scripts/intensity_measurements.py ${args}
    """
}