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
        bigstream_global_steps: 'ransac',
        bigstream_local_steps: 'ransac',
        with_dask_cluster: true,
        bigstream_dask_work_dir: file('work/dask'),
        bigstream_dask_config: '',
        bigstream_with_dask_cluster : true,
        bigstream_workers : 2,
        bigstream_min_workers : 1,
        bigstream_worker_cpus : 1,
        bigstream_worker_mem_gb : 10,
        bigstream_global_align_cpus : 1,
        bigstream_global_align_mem_gb : 10,
        bigstream_local_align_cpus : 1,
        bigstream_local_align_mem_gb : 10,
    ]
}

def adapt_legacy_params_to_bigstream(Map ps) {
    def block_xy_size = registration_xy_stride_param(ps)
    def block_z_size = registration_z_stride_param(ps)
    [
        // spots radius
        bigstream_global_ransac_cc_radius: ps.spots_cc_radius,
        bigstream_local_ransac_cc_radius: ps.spots_cc_radius,
        // spots count
        bigstream_global_ransac_nspots: ps.spots_spot_number,
        bigstream_local_ransac_nspots: ps.spots_spot_number,
        // ransac cutoff
        bigstream_global_ransac_match_threshold: ps.ransac_cc_cutoff,
        bigstream_local_ransac_match_threshold: ps.ransac_cc_cutoff,
        // ransac align threshold
        bigstream_global_ransac_align_threshold: ps.ransac_dist_threshold,
        bigstream_local_ransac_align_threshold: ps.ransac_dist_threshold,
        bistream_local_blocksize: "${block_xy_size},${block_xy_size},${block_z_size}",
        bigstream_local_overlap_factor: 0.125, // 1/8
    ]
}
