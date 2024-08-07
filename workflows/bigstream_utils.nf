include {
    registration_xy_stride_param;
    registration_z_stride_param;
} from '../param_utils'

def get_bigstream_params(Map ps) {
    bigstream_params() +
    adapt_legacy_params_to_bigstream(ps) +
    ps
}

def bigstream_params() {
    return [
        bigstream_global_steps: 'ransac,affine',
        bigstream_local_steps: 'ransac,affine,deform',
        bigstream_dask_work_dir: file('work/dask'),
        bigstream_with_dask_cluster : true,
        bigstream_workers : 2,
        bigstream_global_align_cpus : 1,
        bigstream_global_align_mem_gb : 10,
        bigstream_local_align_cpus : 1,
        bigstream_local_align_mem_gb : 10,
    ]
}

def adapt_legacy_params_to_bigstream(Map ps) {
    def block_xy_size = registration_xy_stride_param(ps)
    def block_z_size = registration_z_stride_param(ps)
    // this is almost empty now because all alignment parameters are in bigstream_config.yml
    [
        bistream_local_blocksize: "${block_xy_size},${block_xy_size},${block_z_size}",
    ]
}
