include { index_channel } from './utils'

include { CELLPOSE      } from '../modules/janelia/cellpose/main'
include { DASK_START    } from '../subworkflows/janelia/dask_start/main'
include { DASK_STOP     } from '../subworkflows/janelia/dask_stop/main'

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
        log.debug "Prepare cluster inputs from $it"
        def (cluster_meta, segmentation_meta, datapaths) = it
        def (in_datapath, out_datapath) = datapaths
        def out_datafile_parent = file(out_datapath).parent
        [
            in_datapath, out_datafile_parent,
        ]
    }
    | collect
    | map {
        // append dask config and cellpose models dir
        def r = it +
                (params.cellpose_work_dir ? [ file(params.cellpose_work_dir) ] : []) +
                (params.dask_config_path ? [ file(params.dask_config_path) ] : []) +
                (params.cellpose_models_dir ? [ file(params.cellpose_models_dir).parent ] : [])
        [
            dask_cluster_meta,
            r
        ]
    } 

    dask_cluster_inputs.subscribe { log.info "Cluster inputs: $it"}

    def dask_work_dir = params.distributed_cellpose
        ? file(params.dask_work_dir)
        : ''

    def dask_cluster_info = DASK_START(
        dask_cluster_inputs,
        params.distributed_cellpose,
        dask_work_dir,
        params.cellpose_dask_workers,
        params.cellpose_required_workers,
        params.cellpose_worker_cpus,
        params.cellpose_worker_memgb,
    )

    dask_cluster_info.subscribe {
        log.debug "Cluster info: $it"
    }

    def cellpose_input = dask_cluster_info
    | combine(indexed_data, by: 0)
    | multiMap { 
        def (cluster_meta, cluster_context, acq_meta, datapaths) = it
        def (input_dir, output_dir) = datapaths
        def dask_config_path_param = params.dask_config_path 
            ? file(dask_config_path_param)
            : []
        def cellpose_models_cache_dir = params.cellpose_models_dir
            ? file(params.cellpose_models_dir)
            : []
        def cellpose_work_dir = params.cellpose_work_dir
            ? file(params.cellpose_work_dir)
            : []
        def data = [
            acq_meta,
            input_dir, "${dapi_channel}/${scale}",
            cellpose_models_cache_dir,
            output_dir,
            "${acq_meta.id}-${scale}-${dapi_channel}.tif",
            cellpose_work_dir,
        ]
        def cluster_info = [
            acq_meta,
            cluster_meta,
            cluster_context,
            cluster_context.scheduler_address,
            dask_config_path_param,
        ]
        log.info "Prepare cellpose input $it -> $data, $cluster_info"
        data: data
        cluster: cluster_info
    }

    def cellpose_results = CELLPOSE(
        cellpose_input.data,
        cellpose_input.cluster.map { it[-2..-1] /*scheduler_address, dask_config*/ },
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
            cluster_meta, cluster_context,
        ]
    }
    | groupTuple
    | DASK_STOP

    segmentation_results = cellpose_results.results
    | map {
        def (acq_meta, input_image, output_image) = it
        [input_image, output_image]
    }

    segmentation_results.subscribe { log.info "Segmentation results: $it" }

    emit:
    segmentation_results

}
