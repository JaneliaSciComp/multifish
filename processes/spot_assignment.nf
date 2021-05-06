process assign_spots {
    container = params.spots_assignment_container
    cpus { cpus }

    input:
    val(labels_path)
    val(spots_path)
    val(output_path)
    val(cpus)

    output:
    tuple val(labels_path), val(spots_path), val(output_path)

    script:
    args_list = [
        labels_path,
        spots_path,
        output_path
    ]
    args = args_list.join(' ')
    """
    umask 0002
    mkdir -p ${output_path}
    echo "python /app/spot_assignment/scripts/assign_spots.py ${args}"
    python /app/spot_assignment/scripts/assign_spots.py ${args}
    """
}
