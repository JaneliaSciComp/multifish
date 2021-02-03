include {
  cut_tiles;
  coarse_spots as fixed_coarse_spots;
  coarse_spots as moving_coarse_spots;
  ransac as coarse_ransac;
  apply_transform as apply_affine_small;
  apply_transform as apply_affine_big;
  spots as fixed_spots;
  spots as moving_spots;
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

workflow prepare_fixed_acq {
    take:
    input_dirs
    output_dirs
    ch
    retiling_scale
    spots_scale
    spots_cc_radius
    spots_spot_number

    main:
    indexed_input_dirs = index_channel(input_dirs)
    indexed_output_dirs = index_channel(output_dirs)

    // prepare tile coordinates
    def tile_cut_res = cut_tiles(
        input_dirs,
        "/${ch}/${retiling_scale}",
        output_dirs.map { "${it}/tiles" },
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    )
    
    def tiles_with_inputs = index_channel(tile_cut_res[0]) | join(index_channel(tile_cut_res[1])) | flatMap {
        def tile_input = it[1]
        it[2].tokenize(' ').collect {
            [ tile_input, it ]
        }
    }

    // get coarse spots
    def coarse_fixed_spots_results = fixed_coarse_spots(
        input_dirs,
        "/${dapi_channel}/${spots_scale}",
        output_dirs.map { "${it}/aff" },
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    )

    // get spots per tile
    def fixed_spots_results = fixed_spots(
        tiles_with_inputs.map { it[0] }, //  image input for the tile
        "/${ch}/${spots_scale}",
        tiles_with_inputs.map { it[1] }, // tile dir 
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) | groupTuple

    def all_fixed_spots_results = coarse_fixed_spots_results | join(fixed_spots_results)

    emit:
    done = all_fixed_spots_results
}

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

    // def fixed_affine_dir = "${working_dir}/aff"
    // def coarse_fixed_spots_results = coarse_spots_fixed(
    //     fixed_input_dir,
    //     "/${dapi_channel}/${affine_scale}",
    //     fixed_affine_dir,
    //     'fixed_spots.pkl',
    //     spots_cc_radius,
    //     spots_spot_number
    // )

    // def coarse_moving_spots_results = coarse_spots_moving(
    //     moving_input_dirs,
    //     "/${dapi_channel}/${affine_scale}",
    //     output_dirs.map { "${it}/aff" },
    //     'moving_spots.pkl',
    //     spots_cc_radius,
    //     spots_spot_number
    // )

    // def indexed_moving_inputs =  index_channel(moving_input_dirs)
    // def indexed_outputs = index_channel(output_dirs)

    // // create all combinations fixed coarse spots with moving coarse spots
    // def coarse_spots_results = coarse_fixed_spots_results.combine(coarse_moving_spots_results)

    // // compute transformation matrix (ransac_affine.mat)
    // def indexed_coarse_ransac_results = coarse_ransac(
    //     coarse_spots_results.map { it[0] }, // fixed spots
    //     coarse_spots_results.map { it[1] }, // moving spots
    //     output_dirs,
    //     'ransac_affine.mat', \
    //     ransac_cc_cutoff,
    //     ransac_dist_threshold
    // ) | join(indexed_outputs, by:1) | map { 
    //     [ 
    //         it[2], //  index
    //         it[1], // full ransac output file path
    //         it[0], // ransac output dir
    //     ]
    // }

    // affine_inputs = indexed_moving_inputs \
    // | combine(fixed_input_dir) \
    // | join(indexed_coarse_ransac_results) \
    // | join
    // | map {
    //     [ 
    //         it[0], // index
    //         it[2], // fixed dir
    //         it[1], // moving dir
    //         it[3], // coarse ransac result
    //         it[4]  // coarse ransac output dir
    //     ]
    // }

    // // compute ransac_affine at affine scale
    // small_affine_results = apply_affine_small(
    //     affine_inputs.map { it[1] },
    //     "/${dapi_channel}/${affine_scale}",
    //     affine_inputs.map { it[2] },
    //     "/${dapi_channel}/${affine_scale}",
    //     affine_inputs.map { it[3] },
    //     affine_inputs.map { "${it[4]}/aff/ransac_affine" },
    //     params.aff_scale_transform_cpus
    // )

    // // compute ransac_affine at deformation scale
    // big_affine_results = apply_affine_big(
    //     affine_inputs.map { it[1] },
    //     "/${dapi_channel}/${deformation_scale}",
    //     affine_inputs.map { it[2] },
    //     "/${dapi_channel}/${deformation_scale}",
    //     affine_inputs.map { it[3] },
    //     affine_inputs.map { "${it[4]}/aff/ransac_affine" },
    //     params.def_scale_transform_cpus
    // )

    // fixed_spots_for_tile([fixed, aff_scale_subpath], \
    //     tiles, "/fixed_spots.pkl", \
    //     params.spots_cc_radius, params.spots_spot_number)

}
