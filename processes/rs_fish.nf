
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
    val(n5_path)
    val(ch)
    val(scale)
    val(spots_voxels)
    val(spots_microns)

    output:
    tuple val(n5_path), val(ch), val(scale), val(spots_microns), val(spots_voxels)

    script:
    args_list = [
        spots_voxels,
        spots_microns,
        n5_path,
        "/$ch/$scale"
    ]
    args = args_list.join(' ')
    """
    echo "python /app/airlocalize/scripts/post_rsfish.py ${args}"
    python /app/airlocalize/scripts/post_rsfish.py ${args}
    """

}
