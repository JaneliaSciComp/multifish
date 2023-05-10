include {
    dask_params;
} from '../external-modules/bigstream/lib/dask_params'

include {
    bigstream_params;
} from '../external-modules/bigstream/lib/bigstream_params'

include {
    registration_xy_stride_param;
    registration_z_stride_param;
} from '../param_utils'

def get_bigstream_params(Map ps) {
    dask_params() +
    bigstream_params() +
    adapt_legacy_params_to_bigstream(ps) +
    ps
}

def adapt_legacy_params_to_bigstream(Map ps) {
    def block_xy_size = registration_xy_stride_param(ps)
    def block_z_size = registration_z_stride_param(ps)
    [
        with_dask_cluster: true,
        // spots radius
        global_ransac_cc_radius: ps.spots_cc_radius,
        local_ransac_cc_radius: ps.spots_cc_radius,
        // spots count
        global_ransac_nspots: ps.spots_spot_number,
        local_ransac_nspots: ps.spots_spot_number,
        // ransac cutoff
        global_ransac_match_threshold: ps.ransac_cc_cutoff,
        local_ransac_match_threshold: ps.ransac_cc_cutoff,
        // ransac align threshold
        global_ransac_align_threshold: ps.ransac_dist_threshold,
        local_ransac_align_threshold: ps.ransac_dist_threshold,
        local_blocksize: "${block_xy_size},${block_xy_size},${block_z_size}",
        local_partition_overlap: 0.125, // 1/8
    ]
}
