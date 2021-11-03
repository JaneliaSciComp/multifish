
process prepare_spots_dirs {
    label 'small'

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

    input:
    val(spots_path)

    output:
    val(spots_path)

    script:
    """
    echo "${spots_path}"
    """

}
