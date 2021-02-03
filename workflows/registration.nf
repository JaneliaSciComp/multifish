include {
  cut_tiles;
  coarse_spots as coarse_spots_fixed;
  coarse_spots as coarse_spots_moving;
  ransac as coarse_ransac;
  apply_transform as apply_affine_small;
  apply_transform as apply_affine_big;
  spots as fixed_spots_for_tile;
  spots as moving_spots_for_tile;
  ransac as ransac_for_tile;
  interpolate_affines;
  deform;
  stitch;
  final_transform;
} from '../processes/registration' addParams(lsf_opts: params.lsf_opts, 
                                             registration_container: params.registration_container)

include {
    index_channel;
} from '../utils/utils'

workflow registration {
    take:
    fixed_input_dir
    working_dir
    moving_input_dirs
    output_dirs
    dapi_channel
    affine_scale
    deformation_scale
    xy_stride
    xy_overlap
    z_stride
    z_overlap
    spots_cc_radius
    spots_spot_number
    ransac_cc_cutoff
    ransac_dist_threshold

    main:
    // prepare tile coordinates
    def tile_dir = "${working_dir}/tiles"
    def tiles = cut_tiles(
        fixed_input_dir,
        "/${dapi_channel}/${deformation_scale}",
        tile_dir,
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ) | flatMap { it.tokenize(' ') }

    def fixed_affine_dir = "${working_dir}/aff"
    def coarse_fixed_spots_results = coarse_spots_fixed(
        fixed_input_dir,
        "/${dapi_channel}/${affine_scale}",
        fixed_affine_dir,
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    )

    def coarse_moving_spots_results = coarse_spots_moving(
        moving_input_dirs,
        "/${dapi_channel}/${affine_scale}",
        output_dirs.map { "${it}/aff" },
        'moving_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    )

    def indexed_moving_inputs =  index_channel(moving_input_dirs)
    def indexed_outputs = index_channel(output_dirs)

    // create all combinations fixed coarse spots with moving coarse spots
    def coarse_spots_results = coarse_fixed_spots_results.combine(coarse_moving_spots_results)

    // compute transformation matrix (ransac_affine.mat)
    def indexed_coarse_ransac_results = coarse_ransac(
        coarse_spots_results.map { it[0] }, // fixed spots
        coarse_spots_results.map { it[1] }, // moving spots
        output_dirs,
        'ransac_affine.mat', \
        ransac_cc_cutoff,
        ransac_dist_threshold
    ) | join(indexed_outputs, by:1) | map { 
        [ 
            it[2], //  index
            it[1], // full ransac output file path
            it[0], // ransac output dir
        ]
    }

    // compute ransac_affine at aff scale
    small_affine_inputs = indexed_moving_inputs \
    | combine(fixed_input_dir) \
    | join(indexed_coarse_ransac_results) \
    | join
    | map {
        [ 
            it[0], // index
            it[2], // fixed dir
            it[1], // moving dir
            it[3], // coarse ransac result
            it[4]  // coarse ransac output dir
        ]
    }

    small_affine_results = apply_affine_small(
        small_affine_inputs.map { it[1] },
        "/${dapi_channel}/${affine_scale}",
        small_affine_inputs.map { it[2] },
        "/${dapi_channel}/${affine_scale}",
        small_affine_inputs.map { it[3] },
        small_affine_inputs.map { "${it[4]}/aff/ransac_affine" },
        params.small_transform_cpus
    )

}
