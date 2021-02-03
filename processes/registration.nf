process cut_tiles {
    container = params.registration_container

    input:
    val(ref_img_path)
    val(ref_img_subpath)
    val(tiles_dir)
    val(xy_stride)
    val(xy_overlap)
    val(z_stride)
    val(z_overlap)

    output:
    env CUT_TILES_RES

    script:
    """
    mkdir -p ${tiles_dir}
    /app/scripts/waitforpaths.sh ${ref_img_path}${ref_img_subpath}
    /entrypoint.sh cut_tiles $ref_img_path $ref_img_subpath $tiles_dir $xy_stride $xy_overlap $z_stride $z_overlap
    CUT_TILES_RES=`ls -d ${tiles_dir}/*[0-9]`
    """
}

process ransac {
    container = params.registration_container

    input:
    val(fixed_spots_file)
    val(moving_spots_file)
    val(output_dir)
    val(output_filename)
    val(cutoff)
    val(threshold)

    output:
    tuple val(output_path), val(output_dir)

    script:
    output_path = "${output_dir}${output_filename}"
    """
    /app/scripts/waitforpaths.sh ${fixed_spots_file} ${moving_spots_file}
    /entrypoint.sh ransac ${fixed_spots_file} ${moving_spots_file} ${output_path} $cutoff $threshold
    """
}

process apply_transform {
    container = params.registration_container
    cpus { cpus }

    input:
    val(ref_img_path)
    val(ref_img_subpath)
    val(mov_img_path)
    val(mov_img_subpath)
    val(txm_path)
    val(output_path)
    val(cpus)

    output:
    tuple val(output_path), val(ref_img_subpath)

    script:
    """
    /app/scripts/waitforpaths.sh ${ref_img_path}${ref_img_subpath} ${mov_img_path}${mov_img_subpath}
    /entrypoint.sh apply_transform_n5 $ref_img_path $ref_img_subpath $mov_img_path $mov_img_subpath $txm_path $output_path
    """
}

process coarse_spots {
    container = params.registration_container

    input:
    val(img_path)
    val(img_subpath)
    val(output_dir)
    val(output_filename)
    val(radius)
    val(spotNum)

    output:
    val(output_path)

    script:
    output_path = "${output_dir}/${output_filename}"
    """
    /app/scripts/waitforpaths.sh ${img_path}${img_subpath}
    /entrypoint.sh spots coarse ${img_path} ${img_subpath} ${output_path} ${radius} ${spotNum}
    """
}

process spots {
    container = params.registration_container

    input:
    val(img_path),
    val(img_subpath)
    val(tile)
    val(output_file)
    val(radius)
    val(spotNum)

    output:
    tuple val(tile), val(output_file)

    script:
    """
    /app/scripts/waitforpaths.sh ${img_path}${img_subpath}
    /entrypoint.sh spots $tile/coords.txt $img_path $img_subpath ${tile}${output_file} $radius $spotNum
    """

}

process interpolate_affines {
    container = params.registration_container

    input:
    val all_tiles
    val tiles_dir

    output:
    val "done"

    script:
    """
    /entrypoint.sh interpolate_affines $tiles_dir
    """
}


process deform {
    container = params.registration_container

    input:
    val(interpolation)
    val(tile)
    val(img_path)
    val(img_subpath)
    val(ransac_affine)
    val(ransac_affine_subpath)
    val(deform_iterations)
    val(deform_auto_mask)

    output:
    val(deform_output)

    script:
    deform_output = "$tile/warp.nrrd"
    """
    /app/scripts/waitforpaths.sh ${img_path}${img_subpath} ${ransac_affine}/${ransac_affine_subpath}
    /entrypoint.sh deform $img_path $img_subpath $ransac_affine $ransac_affine_subpath $tile/coords.txt $deform_output $tile/ransac_affine.mat $tile/final_lcc.nrrd $tile/invwarp.nrrd $deform_iterations $deform_auto_mask
    """
}

process stitch {
    container = params.registration_container
    cpus { cpus }

    input:
    val(deform_outputs)
    val(tile)
    val(xy_overlap)
    val(z_overlap)
    val(img_path)
    val(img_subpath)
    val(ransac_affine_mat)
    val(transform_dir)
    val(invtransform_dir)
    val(output_subpath)
    val(cpus)

    output:
    val(stitch_output)

    script:
    stitch_output = "$transform_dir/$output_subpath"
    """
    /app/scripts/waitforpaths.sh $tile ${img_path}${img_subpath} $ransac_affine_mat
    /entrypoint.sh stitch_and_write $tile $xy_overlap $z_overlap $img_path $img_subpath $ransac_affine_mat $transform_dir $invtransform_dir $output_subpath
    """
}

process final_transform {
    container = params.registration_container
    cpus { cpus }

    input:
    val(stitch_outputs)
    val(ref_img_path)
    val(ref_img_subpath)
    val(mov_img_path)
    val(mov_img_subpath)
    val(txm_path)
    val(output_path)
    val(cpus)

    output:
    tuple val(output_path), val(ref_img_subpath)

    script:
    """
    /app/scripts/waitforpaths.sh ${ref_img_path}${ref_img_subpath} ${mov_img_path}${mov_img_subpath}
    /entrypoint.sh apply_transform_n5 $ref_img_path $ref_img_subpath $mov_img_path $mov_img_subpath $txm_path $output_path
    """
}

