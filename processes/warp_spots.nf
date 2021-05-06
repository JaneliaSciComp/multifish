process collect_merged_points_files {
    label "small"
 
    container { params.registration_container }
 
    input:
    val(merged_points_dir)

    output:
    tuple val(merged_points_dir), env(merged_points_files_res)

    script:
    """
    merged_points_files=`ls ${merged_points_dir}/merged_points_*.txt || true`
    if [[ -z \${merged_points_files} ]]; then
        merged_points_files_res=${merged_points_dir}
    else
        merged_points_files_res=\${merged_points_files}
    fi
    """
}
