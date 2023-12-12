include { DASK_PREPARE        } from '../../../modules/bits/dask/prepare/main'
include { DASK_STARTMANAGER   } from '../../../modules/bits/dask/startmanager/main'
include { DASK_WAITFORMANAGER } from '../../../modules/bits/dask/waitformanager/main'
include { DASK_STARTWORKER    } from '../../../modules/bits/dask/startworker/main'
include { DASK_WAITFORWORKERS } from '../../../modules/bits/dask/waitforworkers/main'

workflow DASK_CLUSTER {
    take:
    meta_and_files       // channel: [val(meta), files...]
    dask_work_dir        // dask work directory
    dask_workers         // int: number of total workers in the cluster
    required_workers     // int: number of required workers in the cluster
    dask_worker_cpus     // int: number of cores per worker
    dask_worker_mem_db   // int: worker memory in GB

    main:
    // prepare dask cluster work dir meta -> [ meta, cluster_work_dir ]
    def dask_prepare_result = DASK_PREPARE(meta_and_files, dask_work_dir)
    
    // start scheduler
    DASK_STARTMANAGER(dask_prepare_result)

    // wait for manager to start
    DASK_WAITFORMANAGER(dask_prepare_result)

    def dask_cluster_info = DASK_WAITFORMANAGER.out.cluster_info

    // prepare inputs for dask workers
    def dask_workers_list = 1..dask_workers

    def dask_workers_input = dask_cluster_info
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
    def cluster = DASK_WAITFORWORKERS(dask_cluster_info, dask_workers, required_workers)

    cluster.cluster_info.subscribe {
        log.debug "Cluster info: $it"
    }

    emit:
    done = cluster.cluster_info // [ meta, cluster_work_dir, scheduler_address, available_workers ]
}
