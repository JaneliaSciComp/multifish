process collect_merged_points_files {
    label "small"
 
    container { params.registration_container }
 
    input:
    val(merged_points_dir)

    output:
    tuple val(merged_points_dir), env(merged_points_files)

    script:
    """
    merged_points_files=`ls ${merged_points_dir}/merged_points_*.txt || true`
    """
}