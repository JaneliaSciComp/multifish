
process prepare_spots_dirs {
    label 'small'

    container { params.airlocalize_container }
    
    input:
    val(spots_path)

    output:
    val(spots_path)

    script:
    """
    mkdir -p ${spots_path}
    """
}

process postprocess_spots {
    label 'small'

    container { params.airlocalize_container }

    input:
    val(spots_path)
    val(output_path)
    val(n5_path)
    val(subpath)

    output:
    val(output_path)

    script:
    args_list = [
        spots_path,
        output_path,
        n5_path,
        subpath
    ]
    args = args_list.join(' ')
    """
    echo "python /app/airlocalize/scripts/post_rsfish.py ${args}"
    python /app/airlocalize/scripts/post_rsfish.py ${args}
    """

}
