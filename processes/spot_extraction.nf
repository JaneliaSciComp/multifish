process cut_tiles {
    container = params.spotextraction_container

    input:
    val(image_path)
    val(ch)
    val(scale)
    val(output_path)
    val(xy_stride)
    val(xy_overlap)
    val(z_stride)
    val(z_overlap)

    output:
    val(image_path)
    env CUT_TILES_RES

    script:
    args_list = [
        "${image_path}",
        "/${ch}/${scale}",
        output_path,
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ]
    args = args_list.join(' ')
    """
    mkdir -p ${output_path}
    echo "python /app/airlocalize/scripts/cut_tiles.py ${args}"
    python /app/airlocalize/scripts/cut_tiles.py ${args}
    CUT_TILES_RES=`ls -d ${output_path}/*[0-9]`
    """
}

process airlocalize {
    container = params.spotextraction_container

    input: 
    val(image_path)
    val(ch)
    val(scale)
    val(coords)
    val(params_filename)
    val(tile_path)
    val(suffix)
    val(dapi_subpath)

    output: 
    tuple val(tile_path), val(ch)

    script:
    args_list = [
        image_path,
        "/${ch}/${scale}",
        coords,
        params_filename,
        tile_path,
        suffix
    ]
    if (dapi_subpath != null && dapi_subpath != '') {
        args_list.add(dapi_subpath)
    }
    args = args_list.join(' ')
    """
    echo "/app/airlocalize/airlocalize.sh ${args}"
    /app/airlocalize/airlocalize.sh ${args}
    """
}

process merge_points {
    container = params.spotextraction_container

    input:
    val(image_path)
    val(ch)
    val(scale)
    val(tiles_dir)
    val(xy_overlap)
    val(z_overlap)
    val(output_path)

    output:
    val(merged_points_path)

    script:
    merged_points_path = "${output_path}/merged_points_${ch}.txt"
    args_list = [
        "${tiles_dir}",
        "_${ch}.txt",
        merged_points_path,
        xy_overlap,
        z_overlap,
        image_path,
        "/${ch}/${scale}"
    ]
    args = args_list.join(' ')
    """
    echo "python /app/airlocalize/scripts/merge_points.py ${args}"
    python /app/airlocalize/scripts/merge_points.py ${args}
    """
}
