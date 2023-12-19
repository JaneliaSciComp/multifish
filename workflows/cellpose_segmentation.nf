include { index_channel;  } from './utils'

include { CELLPOSE;       } from '../modules/bits/cellpose/main'
include { DASK_TERMINATE; } from '../modules/bits/dask/terminate/main'

include { START_DASK;     } from '../subworkflows/bits/start_dask/main'
include { STOP_DASK;      } from '../subworkflows/bits/stop_dask/main'

workflow SEGMENTATION {
    take:
    input_dirs
    acqs
    output_dirs
    dapi_channel
    scale

    main:
    def dask_cluster_meta = [id: 'cellpose_dask_cluster']
    def indexed_data = index_channel(acqs) |
    join(index_channel(input_dirs)) |
    join(index_channel(output_dirs)) |
    map {
        def (index, acq, input_dir, output_dir) = it
        [
            dask_cluster_meta,
            [
                id: acq
            ],
            [
                input_dir,
                output_dir,
            ],
        ]
    }

    // collect all needed paths for the dask cluster
    def dask_cluster_inputs = indexed_data
    | map {
        log.info "Prepare cluster inputs $it -> ${it[-1]}"
        it[-1] // only get the paths
    }
    | collect
    | map {
        [
            dask_cluster_meta,
            it
        ]
    } 

    dask_cluster_inputs.subscribe { log.info "Cluster inputs: $it"}

    def dask_work_dir = params.distributed_cellpose
        ? file(params.dask_work_dir)
        : ''

    def dask_cluster_info = START_DASK(
        dask_cluster_inputs,
        params.distributed_cellpose,
        dask_work_dir,
        params.cellpose_dask_workers,
        params.cellpose_required_workers,
        params.cellpose_worker_cpus,
        params.cellpose_worker_memgb,
    )

    dask_cluster_info.subscribe {
        log.info "Cluster info: $it"
    }

    def cellpose_input = dask_cluster_info
    | combine(indexed_data, by: 0)
    | multiMap { 
        def (cluster_meta, cluster_context, acq_meta, datapaths) = it
        def (input_dir, output_dir) = datapaths
        def dask_config_path_param = params.dask_config_path 
            ? file(dask_config_path_param)
            : []
        def cellpose_models_cache_dir = []
        def data = [
            acq_meta,
            input_dir,
            "${dapi_channel}/${scale}",
            dask_config_path_param,
            cellpose_models_cache_dir,
            output_dir,
            "${acq_meta.id}-${scale}-${dapi_channel}.tif",
        ]
        def cluster_info = [
            acq_meta,
            cluster_meta,
            cluster_context,
            cluster_context.scheduler_address,
        ]
        log.info "Prepare cellpose input $it -> $data, $cluster_info"
        data: data
        cluster: cluster_info
    }

    def cellpose_results = CELLPOSE(
        cellpose_input.data,
        cellpose_input.cluster.map { /*scheduler_address*/it[-1] },
        params.cellpose_driver_cpus,
        params.cellpose_driver_mem_gb,
    )

    cellpose_results.results.subscribe {
        log.info "Cellpose results: $it"
    }

    cellpose_input.cluster.join(cellpose_results.results, by: 0)
    | map {
        def (acq_meta, cluster_meta, cluster_context) = it
        [
            cluster_meta, cluster_context.cluster_work_dir,
        ]
    }
    | groupTuple
    | DASK_TERMINATE

    segmentation_results = cellpose_results.results
    | map {
        def (acq_meta, input_image, output_image) = it
        [input_image, output_image]
    }

    segmentation_results.subscribe { log.info "Segmentation results: $it" }

    emit:
    segmentation_results

}
