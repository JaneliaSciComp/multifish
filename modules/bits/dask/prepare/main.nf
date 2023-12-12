process DASK_PREPARE {
    label 'process_low'
    container { task.ext.container ?: 'bioimagetools/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(data)
    path(dask_work_dir)

    output:
    tuple val(meta), env(cluster_work_fullpath)

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cluster_work_dir=\$(readlink ${dask_work_dir})
    cluster_work_fullpath="\${cluster_work_dir}/${meta.id}"
    /opt/scripts/daskscripts/prepare.sh "\${cluster_work_fullpath}"
    echo "Cluster work dir: \${cluster_work_fullpath}"
    """
}
