process assign_spots {
    container { params.spots_assignment_container }
    cpus { params.assign_spots_cpus }
    memory { params.assign_spots_memory }

    input:
    val(labels_path)
    val(spots_path)
    val(output_path)
    val(n5_path)
    val(subpath)

    output:
    tuple val(labels_path), val(spots_path), val(output_path)

    script:
    args_list = [
        labels_path,
        "\"${spots_path}/spots_*.txt\"",
        output_path,
        n5_path,
        subpath
    ]
    args = args_list.join(' ')
    """
    umask 0002
    mkdir -p ${output_path}
    echo "python /app/scripts/assign_spots.py ${args}"
    python /app/scripts/assign_spots.py ${args}
    """
}
