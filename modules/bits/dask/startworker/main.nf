process DASK_STARTWORKER {
    container { task.ext.container ?: 'bioimagetools/dask:2023.10.1-py11-ol9' }
    cpus { worker_cpus }
    memory "${worker_mem_in_gb} GB"
    clusterOptions { task.ext.cluster_opts }

    input:
    tuple val(meta), path(cluster_work_dir), val(scheduler_address), val(worker_id)
    path(data)
    val(worker_cpus)
    val(worker_mem_in_gb)

    output:
    tuple val(meta), env(cluster_work_fullpath), val(scheduler_address), emit: cluster_info
    path "versions.yml",                                                 emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def container_engine = workflow.containerEngine

    def dask_worker_name = "worker-${worker_id}"
    def dask_scheduler_info_file = "${cluster_work_dir}/dask-scheduler-info.json"
    def terminate_file_name = "${cluster_work_dir}/terminate-dask"

    def dask_worker_work_dir = "${cluster_work_dir}/${dask_worker_name}"
    def dask_worker_pid_file = "${dask_worker_work_dir}/${dask_worker_name}.pid"

    worker_name = dask_worker_name
    worker_dir = dask_worker_work_dir

    """
    cluster_work_fullpath=\$(readlink ${cluster_work_dir})

    /opt/scripts/daskscripts/startworker.sh \
        --container-engine ${container_engine} \
        --name ${dask_worker_name} \
        --worker-dir ${dask_worker_work_dir} \
        --scheduler-address ${scheduler_address} \
        --pid-file ${dask_worker_pid_file} \
        --memory-limit "${worker_mem_in_gb}G" \
        --terminate-file ${terminate_file_name} \
        ${args}

    dask_version=\$(dask --version | grep version | sed "s/.*version\\s*//" )
    cat <<-END_VERSIONS > versions.yml
    "dask": \${dask_version}
    END_VERSIONS
    """
}
