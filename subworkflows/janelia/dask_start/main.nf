process DASK_PREPARE {
    label 'process_low'
    container { task.ext.container ?: 'janeliascicomp/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(data, stageAs: '?/*')
    path(dask_work_dir, stageAs: 'dask_work/*')

    output:
    tuple val(meta), env(cluster_work_fullpath), emit: results
    path(data),                                  emit: data

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

process DASK_STARTMANAGER {
    label 'process_single'
    container { task.ext.container ?: 'janeliascicomp/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(cluster_work_dir, stageAs: 'dask_work/*')
    path(data)

    output:
    tuple val(meta), env(cluster_work_fullpath), emit: cluster_info
    path "versions.yml",                         emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def container_engine = workflow.containerEngine
    
    def dask_scheduler_pid_file ="${cluster_work_dir}/dask-scheduler.pid"
    def dask_scheduler_info_file = "${cluster_work_dir}/dask-scheduler-info.json"
    def terminate_file_name = "${cluster_work_dir}/terminate-dask"

    """
    cluster_work_fullpath=\$(readlink ${cluster_work_dir})

    /opt/scripts/daskscripts/startmanager.sh \
        --container-engine ${container_engine} \
        --pid-file ${dask_scheduler_pid_file} \
        --scheduler-work-dir ${cluster_work_dir} \
        --scheduler-file ${dask_scheduler_info_file} \
        --terminate-file ${terminate_file_name} \
        ${args}

    dask_version=\$(dask --version | grep version | sed "s/.*version\\s*//" )
    cat <<-END_VERSIONS > versions.yml
    "dask": \${dask_version}
    END_VERSIONS
    """
}

process DASK_STARTWORKER {
    container { task.ext.container ?: 'janeliascicomp/dask:2023.10.1-py11-ol9' }
    cpus { worker_cpus }
    memory "${worker_mem_in_gb} GB"
    clusterOptions { task.ext.cluster_opts }

    input:
    tuple val(meta),
          path(cluster_work_dir, stageAs: 'dask_work/*'),
          val(scheduler_address),
          val(worker_id)
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

process DASK_WAITFORMANAGER {
    label 'process_low'
    container { task.ext.container ?: 'janeliascicomp/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta), path(cluster_work_dir, stageAs: 'dask_work/*')

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

process DASK_WAITFORWORKERS {
    label 'process_low'
    container { task.ext.container ?: 'janeliascicomp/dask:2023.10.1-py11-ol9' }

    input:
    tuple val(meta),
          path(cluster_work_dir, stageAs: 'dask_work/*'),
          val(scheduler_address)
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

workflow DASK_START {
    take:
    meta_and_files       // channel: [val(meta), files...]
    distributed          // bool: if true create distributed cluster
    dask_work_dir        // dask work directory
    dask_workers_input   // int: number of total workers in the cluster
    required_workers     // int: number of required workers in the cluster
    dask_worker_cpus     // int: number of cores per worker
    dask_worker_mem_db   // int: worker memory in GB

    main:
    def cluster_info
    if (distributed) {
        // prepare dask cluster work dir meta -> [ meta, cluster_work_dir ]
        def dask_prepare_result = DASK_PREPARE(meta_and_files, dask_work_dir)

        // start scheduler
        DASK_STARTMANAGER(dask_prepare_result.results, dask_prepare_result.data)

        // wait for manager to start
        DASK_WAITFORMANAGER(dask_prepare_result.results)

        // prepare inputs for dask workers
        def dask_workers = dask_workers_input // this is needed because nf complains that dask_workers is already defined
        def dask_workers_list
        if ("${dask_workers}".isNumber()) {
            dask_workers_list = Channel.fromList(1..dask_workers)
        } else {
            dask_workers_list = dask_workers
            | flatMap { nworkers ->
                1..nworkers
            }
        }
        def dask_workers_input = DASK_WAITFORMANAGER.out.cluster_info
        | join(meta_and_files, by: 0)
        | combine(dask_workers_list)
        | multiMap { meta, cluster_work_dir, scheduler_address, data, worker_id ->
            worker_info: [ meta, cluster_work_dir, scheduler_address, worker_id ]
            data: data
        }

        // start dask workers
        DASK_STARTWORKER(dask_workers_input.worker_info,
                        dask_workers_input.data,
                        dask_worker_cpus,
                        dask_worker_mem_db)

        // check dask workers
        def cluster = DASK_WAITFORWORKERS(DASK_WAITFORMANAGER.out.cluster_info,
                                          dask_workers,
                                          required_workers)

        cluster.cluster_info.subscribe {
            // [ meta, cluster_work_dir, scheduler_address, available_workers ]
            log.debug "Cluster info: $it"
        }

        cluster_info = cluster.cluster_info
        | join(meta_and_files, by: 0)
        | map { meta, cluster_work_dir, scheduler_address, available_workers, data ->
            dask_context = [
                scheduler_address: scheduler_address,
                cluster_work_dir: cluster_work_dir,
                available_workers: available_workers,
            ]
            [ meta, dask_context ]
        }
    } else {
        cluster_info = meta_and_files
        | map { meta, data ->
            [ meta, [:] ]
        }
    }

    emit:
    done = cluster_info // [ meta, dask_context ]
}
