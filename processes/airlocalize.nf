process cut_tiles {
    label 'small'

    container { params.airlocalize_container }

    input:
    val(image_path)
    val(ch)
    val(scale)
    val(tiles_dir)
    val(xy_stride)
    val(xy_overlap)
    val(z_stride)
    val(z_overlap)

    output:
    tuple val(image_path), env(CUT_TILES_RES)

    script:
    args_list = [
        "${image_path}",
        "/${ch}/${scale}",
        tiles_dir,
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ]
    args = args_list.join(' ')
    """
    umask 0002
    mkdir -p ${tiles_dir}
    echo "python /app/airlocalize/scripts/cut_tiles.py ${args}"
    python /app/airlocalize/scripts/cut_tiles.py ${args}
    CUT_TILES_RES=`ls -d ${tiles_dir}/*[0-9]`
    """
}

process run_airlocalize {
    container = params.airlocalize_container
    cpus { params.airlocalize_cpus }
    memory { params.airlocalize_memory }

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
    tuple val(image_path), val(tile_path), val(ch)

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
    export SCRATCH_DIR=${params.local_scratch_dir}
    echo "SCRATCH_DIR: \$SCRATCH_DIR"
    echo "/app/airlocalize/airlocalize.sh ${args}"
    /app/airlocalize/airlocalize.sh ${args}
    """
}

process merge_points {
    label 'small'

    container { params.airlocalize_container }

    input:
    val(image_path)
    val(ch)
    val(scale)
    val(tiles_dir)
    val(xy_overlap)
    val(z_overlap)
    val(output_path)

    output:
    tuple val(image_path), val(ch), val(scale), val(output_microns)

    script:
    output_microns = "${output_path}/spots_${ch}.txt"
    output_voxels = "${output_path}/spots_airlocalize_${ch}.csv"
    args_list = [
        "\"${tiles_dir}/*/air_localize_points_${ch}.txt\"",
        output_microns,
        output_voxels,
        xy_overlap,
        z_overlap,
        image_path,
        "/${ch}/${scale}",
        "/${ch}/s0"
    ]
    args = args_list.join(' ')
    """
    umask 0002
    mkdir -p ${output_path}
    echo "python /app/airlocalize/scripts/merge_points.py ${args}"
    python /app/airlocalize/scripts/merge_points.py ${args}
    """
}
