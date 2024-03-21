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
    if [[ "${dask_work_dir}" == "" ]]; then
        dwork="dask-\$(date -I)"
        mkdir -p \${dwork}
        cluster_work_dir=\$(readlink -e \${dwork})
    else
        cluster_work_dir=\$(readlink ${dask_work_dir})
    fi
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
    path(data, stageAs: '?/*')

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
    path(data, stageAs: '?/*')
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
    total_workers        // int: number of total workers in the cluster
    required_workers     // int: number of required workers in the cluster
    dask_worker_cpus     // int: number of cores per worker
    dask_worker_mem_db   // int: worker memory in GB

    main:
    def dask_clusters = meta_and_files
    | combine(as_value_channel(distributed))
    | combine(as_value_channel(dask_work_dir))
    | combine(as_value_channel(total_workers))
    | combine(as_value_channel(required_workers))
    | combine(as_value_channel(dask_worker_cpus))
    | combine(as_value_channel(dask_worker_mem_db))
    | branch {
        def (meta, data, distributed_flag, work_dir, n_workers, min_workers, cpus, mem_gb) = it
        log.info "Prepare cluster input: $it"
        needed: distributed_flag
        not_needed: !(distributed_flag)
    }

    def not_started_clusters = dask_clusters.not_needed
    | map {
        def (meta) = it
        [ meta, [:] ]
    }

    def dask_prepare_input = dask_clusters.needed
    | map {
        def (meta, data, distributed_flag, work_dir, n_workers, min_workers, cpus, mem_gb) = it
        [ 
            meta,
            data ?: [],
            work_dir ?: [],
            n_workers,
            min_workers,
            cpus,
            mem_gb,
        ]
    }

    // prepare dask cluster work dir meta -> [ meta, cluster_work_dir ]
    def dask_prepare_result = DASK_PREPARE(
        dask_prepare_input.map { it[0..1] }, // meta and data
        dask_prepare_input.map { it[2] }, // dask work dir
    )

    // start scheduler
    DASK_STARTMANAGER(dask_prepare_result.results, dask_prepare_result.data)

    // wait for manager to start
    DASK_WAITFORMANAGER(dask_prepare_result.results)

    // prepare inputs for dask workers
    def dask_workers_input = DASK_WAITFORMANAGER.out.cluster_info
    | join(dask_prepare_input, by: 0)
    | map {
        def (meta, cluster_work_dir, scheduler_address, data, work_dir, n_workers, min_workers, cpus, mem_gb) = it
        def r = [
            meta, cluster_work_dir, scheduler_address, n_workers, min_workers, data, cpus, mem_gb,
        ]
        log.info "Dask workers input: $r"
        r
    }

    def per_worker_input = dask_workers_input
    | flatMap {
        def (meta, cluster_work_dir, scheduler_address, n_workers, min_workers, data, cpus, mem_gb) = it
        (1..n_workers).collect { worker_id -> 
            def r = [ meta, cluster_work_dir, scheduler_address, worker_id, data, cpus, mem_gb ]
            log.info "Single dask worker input: $r"
            r
        }
    }

    // start dask workers
    DASK_STARTWORKER(per_worker_input.map { it[0..3] }, // meta, cluster_work_dir, scheduler_address, worker_id
                     per_worker_input.map { it[4] }, // data
                     per_worker_input.map { it[5] }, // cpus
                     per_worker_input.map { it[6] }, // mem
    )

    dask_workers_input | view

    // check dask workers
    def cluster = DASK_WAITFORWORKERS(dask_workers_input.map { it[0..2] }, // meta, cluster_work_dir, scheduler_address
                                      dask_workers_input.map { it[3] }, // n_workers
                                      dask_workers_input.map { it[4] }, // min_workers
    )

    cluster.cluster_info.subscribe {
        // [ meta, cluster_work_dir, scheduler_address, available_workers ]
        log.debug "Cluster info: $it"
    }

    def started_clusters = cluster.cluster_info
    | map { meta, cluster_work_dir, scheduler_address, available_workers ->
        dask_context = [
            scheduler_address: scheduler_address,
            cluster_work_dir: cluster_work_dir,
            available_workers: available_workers,
        ]
        [ meta, dask_context ]
    }

    emit:
    done = started_clusters.concat (not_started_clusters) // [ meta, dask_context ]
}

def as_value_channel(v) {
    if (!v.toString().contains("Dataflow")) {
        Channel.value(v)
    } else if (!v.toString().contains("value")) {
        // if not a value channel return the first value
        v.first()
    } else {
        // this is a value channel
        v
    }
}