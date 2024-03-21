include {
    get_bigstream_params;
} from './bigstream_utils'

all_bigstream_params = get_bigstream_params(params)

include {
    BIGSTREAM_REGISTRATION;
} from '../subworkflows/janelia/bigstream_registration/main' addParams(all_bigstream_params)

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

        def meta = [
            id: "${fixed_acq_name}-${moving_acq_name}",
        ]
        // additional deformation input
        def additional_deforms = warped_channels.collect { warped_ch ->
            [
                moving,
                "${warped_ch}/${deformation_scale}",
                "${output}/warped",
            ]
        }
        def bigstream_dask_work_dir = params.bigstream_dask_work_dir instanceof String && params.bigstream_dask_work_dir
            ? file(params.bigstream_dask_work_dir)
            : ''
        // registration input
        def ri =  [
            meta,
            fixed, // global_fixed
            "${reg_ch}/${affine_scale}", // global_fixed_subpath
            moving, // global_moving
            "${reg_ch}/${affine_scale}", // global_moving_subpath
            '', '', // global_fixed_mask, global_fixed_mask_dataset
            '', '', // global_moving_mask, global_fixed_moving_dataset
            params.bigstream_global_steps,
            output,
            "aff/ransac_affine.mat", // global_transform_name
            "aff/ransac_affine",     // global_aligned_name
            fixed, // local_fixed
            "${reg_ch}/${deformation_scale}", // local_fixed_subpath
            moving, // local_moving
            "${reg_ch}/${deformation_scale}", // local_moving_subpath
            '', '', // local_fixed_mask, local_fixed_mask_dataset
            '', '', // local_moving_mask, local_fixed_moving_dataset
            params.bigstream_local_steps,
            output,
            "transform",  // local_transform_name
            "${deformation_scale}", // local_transform_dataset
            "invtransform", // local_inv_transform_name
            "${deformation_scale}", // local_inv_transform_dataset
            '', // local_aligned_name (skip local warping because we do it for all channels as additional deform)
            additional_deforms,
            params.bigstream_with_dask_cluster,
            bigstream_dask_work_dir,
            params.bigstream_dask_config,
            params.bigstream_workers,
            params.bigstream_min_workers,
            params.bigstream_worker_cpus,
            params.bigstream_worker_mem_gb,
        ]
        log.debug "Prepared bigstream inputs: ${ri}"
        ri
    }

    def bigstream_results = BIGSTREAM_REGISTRATION(
        bigstream_input,
        params.bigstream_global_align_cpus,
        params.bigstream_global_align_mem_gb,
        params.bigstream_local_align_cpus,
        params.bigstream_local_align_mem_gb,
    )

    def registration_results = bigstream_results.local
    | map {
        def (
            meta,
            local_fixed, local_fixed_subpath,
            local_moving, local_moving_subpath,
            global_output, global_transform_name,
            local_output,
            local_transform_name, local_transform_subpath,
            local_inv_transform_name, local_inv_transform_subpath,
            local_aligned_name
        ) = it
        def r = [
            local_fixed, local_fixed_subpath,
            local_moving, local_moving_subpath,
            "${local_output}/${local_transform_name}", // dir transform
            "${local_output}/${local_inv_transform_name}", // dir inv transform
            "${local_output}/warped", // output
        ]
        log.debug "Bigstream results $it -> $r"
        r
    }

    emit:
    done = registration_results
}
