process cut_tiles {
    container = "${params.mfrepo}/spotextraction:1.0"

    input:
    tuple val(image_path),
          val(channel),
          val(scale),
          val(output_path),
          val(xy_stride),
          val(xy_overlap),
          val(z_stride),
          val(z_overlap)

    output:
    val(output_path)

    script:
    args_list = [
        image_path,
        "${channel}/${scale}",
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
    """
}

process airlocalize {
    container = "${params.mfrepo}/spotextraction:1.0"

    input: 
    tuple val(image_path),
          val(channel),
          val(scale),
          val(coords),
          val(params_filename),
          val(output),
          val(suffix),
          val(dapi_subpath)

    output: 
    val(output)

    script:
    args_list = [
        image_path,
        "${channel}/${scale}",
        coords,
        params_filename,
        output,
        suffix
    ]
    if (dapi_subpath != null && dapi_subpath != '') {
        args_list.add(dapi_subpath)
    }
    args = args_list.join(' ')
    """
    echo "python /app/airlocalize/scripts/air_localize_mcr.py ${args}"
    python /app/airlocalize/scripts/air_localize_mcr.py ${args}
    """
}

def val_or_default(val, default_val) {
    return val == null || val == '' ? default_val : val
}

def process_log(work_dir, logname) {
    return "${work_dir}/${logname}.log"
}
