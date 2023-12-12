process DASK_WAITFORMANAGER {
    label 'process_low'
    container { task.ext.container ?: 'bioimagetools/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(cluster_work_dir)

    output:
    tuple val(meta), env(cluster_work_fullpath), env(scheduler_address), emit: cluster_info
    path "versions.yml",                                                 emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def dask_scheduler_info_file = "${cluster_work_dir}/dask-scheduler-info.json"
    def terminate_file_name = "${cluster_work_dir}/terminate-dask"

    """
    cluster_work_fullpath=\$(readlink ${cluster_work_dir})

    /opt/scripts/daskscripts/waitformanager.sh \
        --flist "${dask_scheduler_info_file},${terminate_file_name}" \
        ${args}

    if [[ -e "${dask_scheduler_info_file}" ]] ; then
        echo "\$(date): Get cluster info from ${dask_scheduler_info_file}"
        scheduler_address=\$(jq ".address" ${dask_scheduler_info_file})
    else
        echo "\$(date): Cluster info file ${dask_scheduler_info_file} not found"
        scheduler_address=
    fi

    dask_version=\$(dask --version | grep version | sed "s/.*version\\s*//" )
    cat <<-END_VERSIONS > versions.yml
    "dask": \${dask_version}
    END_VERSIONS
    """

}