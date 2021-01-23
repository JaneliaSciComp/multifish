
process cut_tiles {
    container = "/groups/scicompsoft/home/rokickik/dev/multifish/containers/bigstream/out.sif"

    input:
    val ref_img_path
    val ref_img_subpath
    val tiles_dir
    val xy_stride
    val xy_overlap
    val z_stride
    val z_overlap

    output:
    val "${tiledir}/0/coords.txt"

    script:
    """
    /app/scripts/waitforpaths.sh $ref_img_path/$ref_img_subpath
    /entrypoint.sh cut_tiles $ref_img_path $ref_img_subpath $tiles_dir $xy_stride $xy_overlap $z_stride $z_overlap
    """
}

process coarse_spots {
    container = "/groups/scicompsoft/home/rokickik/dev/multifish/containers/bigstream/out.sif"

    input:
    val img_path
    val img_subpath
    val output_file
    val radius
    val spotNum

    output:
    val output_file

    script:
    """
    /app/scripts/waitforpaths.sh $img_path/$img_subpath
    /entrypoint.sh spots coarse $img_path $img_subpath $output_file $radius $spotNum
    """

}

process coarse_ransac {
    container = "/groups/scicompsoft/home/rokickik/dev/multifish/containers/bigstream/out.sif"

    input:
    val fixed_spots
    val moving_spots
    val output_file
    val cutoff
    val threshold

    output:
    val output_file

    script:
    """
    /app/scripts/waitforpaths.sh $fixed_spots $moving_spots
    /entrypoint.sh ransac $fixed_spots $moving_spots $output_file $cutoff $threshold
    """
}

process apply_transform {
    container = "/groups/scicompsoft/home/rokickik/dev/multifish/containers/bigstream/out.sif"

    input:
    val cpus
    val ref_img_path
    val ref_img_subpath
    val mov_img_path
    val mov_img_subpath
    val txm_path
    val output_path
    val points_path

    output:
    tuple val(output_path), val(ref_img_subpath)

    cpus "$cpus"

    script:
    """
    /app/scripts/waitforpaths.sh ${ref_img_path}${ref_img_subpath} ${mov_img_path}${mov_img_subpath}
    /entrypoint.sh apply_transform_n5 $ref_img_path $ref_img_subpath $mov_img_path $mov_img_subpath $txm_path $output_path $points_path
    """
}

process spots {
    container = "/groups/scicompsoft/home/rokickik/dev/multifish/containers/bigstream/out.sif"

    input:
    val tile
    val img_path
    val img_subpath
    val output_file
    val radius
    val spotNum

    output:
    val output_file

    script:
    """
    /app/scripts/waitforpaths.sh $img_path/$img_subpath
    /entrypoint.sh spots $tile/coords.txt $img_path $img_subpath $output_file $radius $spotNum
    """

}

