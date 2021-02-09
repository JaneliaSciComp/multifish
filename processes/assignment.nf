process assign_spots {
    container = params.spots_assignment_container

    input:
    val(labels_path)
    val(spots_path)
    val(output_path)

    output:
    tuple val(spots_path), val(output_path)

    script:
    args_list = [
        labels_path,
        spots_path,
        output_path
    ]
    args = args_list.join(' ')
    """
    echo "python /app/spot_assignment/scripts/assign_spots.py ${args}"
    python /app/spot_assignment/scripts/assign_spots.py ${args}
    """
}

process quantify_spots {
    container = params.spots_assignment_container

    input:
    val(labels_path)
    val(registered_image_path)
    val(round)
    val(ch)
    val(scale)
    val(output_path)

    output:
    tuple val(spots_path), val(output_path)

    script:
    args_list = [
        labels_path,
        registered_image_path,
        output_path,
        round,
        ch,
        scale
    ]
    args = args_list.join(' ')
    """
    echo "python /app/intensity_measurement/scripts/intensity_measurements.py ${args}"
    python /app/intensity_measurement/scripts/intensity_measurements.py ${args}
    """
}