process DASK_TERMINATE {
    label 'process_low'
    container { task.ext.container ?: 'bioimagetools/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(cluster_work_dir)

    output:
    tuple val(meta), env(cluster_work_fullpath)

    when:
    task.ext.when == null || task.ext.when

    script:
    def cluster_work_path = cluster_work_dir
    def terminate_file_name = "${cluster_work_path}/terminate-dask"
    """
    cluster_work_fullpath=\$(readlink ${cluster_work_dir})

    echo "\$(date): Terminate DASK Scheduler: ${cluster_work_path}"
    echo $PWD
    cat > ${terminate_file_name} <<EOF
    \$(date)
    DONE
    EOF

    cat ${terminate_file_name}
    """
}
