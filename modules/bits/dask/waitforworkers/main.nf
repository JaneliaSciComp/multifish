process DASK_WAITFORWORKERS {
    label 'process_low'
    container { task.ext.container ?: 'bioimagetools/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(cluster_work_dir), val(scheduler_address)
    val(total_workers)
    val(required_workers)

    output:
    tuple val(meta), env(cluster_work_fullpath), val(scheduler_address), env(available_workers), emit: cluster_info
    path "versions.yml",                                                                         emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def container_engine = workflow.containerEngine
    
    def terminate_file_name = "${cluster_work_dir}/terminate-dask"

    cluster_work_fullpath = cluster_work_dir.resolveSymLink().toString()

    """
    cluster_work_fullpath=\$(readlink ${cluster_work_dir})

    # waitforworkers.sh sets available_workers variable
    . /opt/scripts/daskscripts/waitforworkers.sh \
        --cluster-work-dir ${cluster_work_dir} \
        --scheduler-address ${scheduler_address} \
        --total-workers ${total_workers} \
        --required-workers ${required_workers} \
        --terminate-file ${terminate_file_name} \
        ${args}

    dask_version=\$(dask --version | grep version | sed "s/.*version\\s*//" )
    cat <<-END_VERSIONS > versions.yml
    "dask": \${dask_version}
    END_VERSIONS
    """
}
