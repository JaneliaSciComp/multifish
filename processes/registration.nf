process cut_tiles {
    label 'small'

    container { params.registration_container }

    input:
    val(image_path)
    val(image_subpath)
    val(tiles_dir)
    val(xy_stride)
    val(xy_overlap)
    val(z_stride)
    val(z_overlap)

    output:
    tuple val(image_path), env(CUT_TILES_RES)

    script:
    """
    umask 0002
    mkdir -p ${tiles_dir}
    /app/scripts/waitforpaths.sh ${image_path}${image_subpath}
    /entrypoint.sh cut_tiles $image_path $image_subpath $tiles_dir $xy_stride $xy_overlap $z_stride $z_overlap
    CUT_TILES_RES=`ls -d ${tiles_dir}/*[0-9]`
    """
}

process ransac {
    container { params.registration_container }
    cpus { params.ransac_cpus }
    memory { params.ransac_memory }

    input:
    val(fixed_spots_file) // fixed spots pkl
    val(moving_spots_file) // moving spots pkl
    val(output_dir)
    val(output_filename)
    val(cutoff)
    val(threshold)

    output:
    tuple val(output_dir), val(output_path)

    script:
    output_path = "${output_dir}/${output_filename}"
    """
    umask 0002
    mkdir -p ${output_dir}
    /app/scripts/waitforpaths.sh ${fixed_spots_file} ${moving_spots_file}
    /entrypoint.sh ransac ${fixed_spots_file} ${moving_spots_file} ${output_path} $cutoff $threshold
    """
}

process apply_transform {
    container { params.registration_container }
    cpus { cpus }
    memory { memory }

    input:
    val(ref_image_path)
    val(ref_image_subpath)
    val(mov_image_path)
    val(mov_image_subpath)
    val(txm_path)
    val(output_path)
    val(points_path)
    val(cpus)
    val(memory)

    output:
    tuple val(output_path), val(ref_image_subpath)

    script:
    def output_parent_dir = file(output_path).parent
    def args_list = [
        ref_image_path,
        ref_image_subpath,
        mov_image_path,
        mov_image_subpath,
        txm_path,
        output_path,
        points_path
    ]
    def args = args_list.join(' ')
    """
    echo "Apply transform"
    umask 0002
    mkdir -p ${output_parent_dir}
    # Must remove the output directory, or we get a zarr.errors.ContainsArrayError if it already exists
    rm -rf ${output_path}${ref_image_subpath} || true
    /app/scripts/waitforpaths.sh ${ref_image_path}${ref_image_subpath} ${mov_image_path}${mov_image_subpath} ${txm_path}
    /entrypoint.sh apply_transform_n5 ${args}
    """
}

process coarse_spots {
    container { params.registration_container }
    cpus { params.coarse_spots_cpus }
    memory { params.coarse_spots_memory }

    input:
    val(image_path)
    val(image_subpath)
    val(output_dir)
    val(output_filename)
    val(radius)
    val(spotNum)

    output:
    tuple val(image_path), val(output_dir), val(output_path)

    script:
    output_path = "${output_dir}/${output_filename}"
    """
    umask 0002
    mkdir -p ${output_dir}
    /app/scripts/waitforpaths.sh ${image_path}${image_subpath}
    /entrypoint.sh spots coarse ${image_path} ${image_subpath} ${output_path} ${radius} ${spotNum}
    """
}

process spots {
    container { params.registration_container }
    cpus { params.spots_cpus }
    memory { params.spots_memory }

    input:
    val(image_path)
    val(image_subpath)
    val(tile_dir)
    val(output_filename)
    val(radius)
    val(spotNum)

    output:
    tuple val(image_path), val(tile_dir), val(output_path)

    script:
    output_path = "${tile_dir}/${output_filename}"
    """
    /app/scripts/waitforpaths.sh ${image_path}${image_subpath}
    /entrypoint.sh spots ${tile_dir}/coords.txt ${image_path} ${image_subpath} ${output_path} ${radius} ${spotNum}
    """
}

process interpolate_affines {
    container { params.registration_container }
    cpus { params.interpolate_cpus }
    memory { params.interpolate_memory }

    input:
    val(tiles_dir)

    output:
    val(interpolated_dir)

    script:
    interpolated_dir = tiles_dir
    """
    umask 0002
    /entrypoint.sh interpolate_affines ${interpolated_dir}
    """
}


process deform {
    container { params.registration_container }
    cpus { params.deform_cpus }
    memory { params.deform_memory }

    input:
    val(tile)
    val(image_path)
    val(image_subpath)
    val(ransac_affine)
    val(ransac_affine_subpath)
    val(deform_iterations)
    val(deform_auto_mask)

    output:
    tuple val(tile), val(image_path), val(deform_output)

    script:
    deform_output = "$tile/warp.nrrd"
    """
    umask 0002
    /app/scripts/waitforpaths.sh ${image_path}${image_subpath} ${ransac_affine}${ransac_affine_subpath}
    /entrypoint.sh deform $image_path $image_subpath $ransac_affine $ransac_affine_subpath $tile/coords.txt $deform_output $tile/ransac_affine.mat $tile/final_lcc.nrrd $tile/invwarp.nrrd $deform_iterations $deform_auto_mask
    """
}

process stitch {
    container { params.registration_container }
    cpus { params.registration_stitch_cpus }
    memory { params.registration_stitch_memory }

    input:
    val(tile)
    val(xy_overlap)
    val(z_overlap)
    val(image_path)
    val(image_subpath)
    val(ransac_affine_mat)
    val(output_dir)
    val(output_subpath)

    output:
    tuple val(tile),
          val(image_path),
          val(output_dir),
          val(transform_dir),
          val(invtransform_dir)

    script:
    transform_dir = "${output_dir}/transform"
    invtransform_dir = "${output_dir}/invtransform"
    """
    umask 0002
    /app/scripts/waitforpaths.sh $tile ${image_path}${image_subpath} $ransac_affine_mat
    /entrypoint.sh stitch_and_write $tile $xy_overlap $z_overlap $image_path $image_subpath $ransac_affine_mat $transform_dir $invtransform_dir $output_subpath
    """
}

process final_transform {
    container { params.registration_container }
    cpus { params.registration_transform_cpus }
    memory { params.registration_transform_memory }

    input:
    val(ref_image_path)
    val(ref_image_subpath)
    val(mov_image_path)
    val(mov_image_subpath)
    val(txm_path)
    val(output_path)

    output:
    tuple val(ref_image_path),
          val(ref_image_subpath),
          val(mov_image_path),
          val(mov_image_subpath),
          val(txm_path),
          val(output_path)

    script:
    """
    echo "Final transform"
    # Must remove the output directory, or we get a zarr.errors.ContainsArrayError if it already exists
    rm -rf ${output_path}${ref_image_subpath} || true
    umask 0002
    /app/scripts/waitforpaths.sh ${ref_image_path}${ref_image_subpath} ${mov_image_path}${mov_image_subpath}
    /entrypoint.sh apply_transform_n5 $ref_image_path $ref_image_subpath $mov_image_path $mov_image_subpath $txm_path $output_path
    echo "Finished final transform for ${output_path}${ref_image_subpath}"
    """
}

