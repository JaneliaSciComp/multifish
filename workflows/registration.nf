include {
    registration as bigstream_registration;
} from './bigstream_registration'

include {
    registration as legacy_registration;
} from './legacy_registration'

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
    if (params.use_bigstream) {
        done = bigstream_registration(
            registration_input,
            reg_ch,
            xy_stride,
            xy_overlap,
            z_stride,
            z_overlap,
            affine_scale,
            deformation_scale,
            spots_cc_radius,
            spots_spot_number,
            ransac_cc_cutoff,
            ransac_dist_threshold,
            deform_iterations,
            deform_auto_mask,
            warped_channels
        )
    } else {
        done = legacy_registration(
            registration_input,
            reg_ch,
            xy_stride,
            xy_overlap,
            z_stride,
            z_overlap,
            affine_scale,
            deformation_scale,
            spots_cc_radius,
            spots_spot_number,
            ransac_cc_cutoff,
            ransac_dist_threshold,
            deform_iterations,
            deform_auto_mask,
            warped_channels
        )
    }

    emit:
    done
}
