include {
    dask_params;
} from '../external-modules/bigstream/lib/dask_params'

include {
    bigstream_params;
} from '../external-modules/bigstream/lib/bigstream_params'

all_bigstream_params = get_bigstream_params(params)

include {
    BIGSTREAM_REGISTRATION;
} from '../external-modules/bigstream/subworkflows/bigstream-registration' addParams(all_bigstream_params)

workflow registration {
    take:
    registration_input // [0 - fixed_acq name,
                       //  1 - fixed image
                       //  2 - moving_acq name
                       //  3 - moving image
                       //  4 - output dir]
    reg_ch // registered image channel (value)
    xy_stride // xy_stride - ignored - bigstream will use params.local_partitionsize
    xy_overlap // ignored
    z_stride // ignored - will use the same value as xy_stride
    z_overlap // ignored
    affine_scale
    deformation_scale
    spots_cc_radius
    spots_spot_number
    ransac_cc_cutoff
    ransac_dist_threshold
    deform_iterations
    deform_auto_mask
    warped_channels

    main:
    def bigstream_input = registration_input
    | map {
        def (fixed_acq_name,
             fixed,
             moving_acq_name,
             moving,
             output) = it
        // registration input
        def ri =  [
            fixed, // global_fixed
            "${reg_ch}/${affine_scale}", // global_fixed_subpath
            moving, // global_moving
            "${reg_ch}/${affine_scale}", // global_moving_subpath
            params.global_steps,
            output,
            "aff/ransac_affine.mat", // global_transform_name
            "aff/ransac_affine",     // global_aligned_name
            fixed, // local_fixed
            "${reg_ch}/${deformation_scale}", // local_fixed_subpath
            moving, // local_moving
            "${reg_ch}/${deformation_scale}", // local_moving_subpath
            params.local_steps,
            output,
            "transform",  // local_transform_name
            "warped", // local_aligned_name
        ]
        // additional deformation input
        def additional_deforms = warped_channels.collect { warped_ch ->
            [
                fixed,
                "${warped_ch}/${deformation_scale}",
                "${output}/warped"
            ]
        }
        [
            ri,
            additional_deforms
        ]
    }

    def bigstream_results = BIGSTREAM_REGISTRATION(
        bigstream_input.map { it[0] },
        bigstream_input.map { it[1] }
    )

    def registration_results = bigstream_results
    | map {
        def (
            global_fixed, global_fixed_dataset,
            global_moving, global_moving_dataset,
            global_output,
            global_transform_name,
            global_aligned_name,
            local_fixed, local_fixed_dataset,
            local_moving, local_moving_dataset,
            local_output,
            local_transform_name,
            local_aligned_name,
            deformed_results
        ) = it
        def r = [
            local_fixed, // fixed
            local_fixed_dataset, // fixed_subpath
            local_moving, // moving
            local_moving_dataset, // moving subpath
            "${local_output}/${local_transform_name}", // dir transform
            '', // inv transform
            "${local_output}/${local_aligned_name}", // output
        ]
    }

    emit:
    done = registration_results
}

def get_bigstream_params(Map ps) {
    dask_params() +
    bigstream_params() +
    adapt_legacy_params_to_bigstream(ps) +
    ps
}

def adapt_legacy_params_to_bigstream(Map ps) {
    def partitionsize = 0
    if (ps.registration_xy_stride) {
        partitionsize = ps.registration_xy_stride
    } else if (ps.registration_z_stride) {
        partitionsize = ps.registration_z_stride
    } else {
        partitionsize = 256
    }
    [
        global_steps: 'ransac,affine',
        local_steps: 'ransac,deform',
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
        local_partitionsize: partitionsize,
        local_partition_overlap: 0.125, // 1/8
    ]
}
