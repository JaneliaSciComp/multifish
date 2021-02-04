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
    xy_stride
    xy_overlap
    z_stride
    z_overlap
    spots_scale
    spots_cc_radius
    spots_spot_number

    main:
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
        "/${ch}/${spots_scale}",
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
    all_fixed_spots_results.subscribe { println "Fixed spots results: ${it}" }

    emit:
    done = all_fixed_spots_results
}

workflow registration {
    take:
    fixed_name
    fixed_input_dir
    fixed_output_dir
    moving_names
    moving_input_dirs
    moving_output_dirs
    ch
    xy_stride
    xy_overlap
    z_stride
    z_overlap
    affine_scale
    deformation_scale
    spots_cc_radius
    spots_spot_number
    ransac_cc_cutoff
    ransac_dist_threshold

    main:
    // prepare tile coordinates
    def tile_cut_res = cut_tiles(
        fixed_input_dir,
        "/${ch}/${deformation_scale}",
        fixed_output_dir.map { "${it}/tiles" },
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

    // get fixed coarse spots
    def indexed_coarse_fixed_spots_results = index_coarse_results(
        fixed_name,
        fixed_input_dir, 
        fixed_coarse_spots(
            fixed_input_dir,
            "/${ch}/${affine_scale}",
            fixed_output_dir.map { "${it}/aff" },
            'fixed_spots.pkl',
            spots_cc_radius,
            spots_spot_number
        ))

    // get fixed spots per tile
    def fixed_spots_results = fixed_spots(
        tiles_with_inputs.map { it[0] }, //  image input for the tile
        "/${ch}/${affine_scale}",
        tiles_with_inputs.map { it[1] }, // tile dir 
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) | groupTuple // group  results by input path

    // get moving coarse spots
    def indexed_coarse_moving_spots_results = index_coarse_results(
        moving_names,
        moving_input_dirs,
        moving_coarse_spots(
            moving_input_dirs,
            "/${ch}/${affine_scale}",
            moving_output_dirs.map { "${it}/aff" },
            'moving_spots.pkl',
            spots_cc_radius,
            spots_spot_number
        ))

    // // create all combinations fixed coarse spots with moving coarse spots
    def coarse_ransac_inputs = indexed_coarse_fixed_spots_results \
    | combine(indexed_coarse_moving_spots_results) \
    | map {
        println "Coarse ransac input: $it"; it}

    // compute transformation matrix (ransac_affine.mat)
    def indexed_coarse_ransac_results = coarse_ransac(
        coarse_ransac_inputs.map { it[3] }, // fixed spots
        coarse_ransac_inputs.map { it[8] }, // moving spots
        coarse_ransac_inputs.map { get_moving_results_dir(it[9], it[0], it[5]) },
        'ransac_affine.mat', \
        ransac_cc_cutoff,
        ransac_dist_threshold
    )

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

    emit:
    done = coarse_ransac_inputs
}

def index_coarse_results(name, coarse_inputs, coarse_results) {
    def indexed_name = index_channel(name)
    def indexed_coarse_inputs = index_channel(coarse_inputs)

    coarse_results | map { 
        [ it[1], it[0] ] // swap input path with coarse result path
    } \
    | join(indexed_coarse_inputs, by:1) \
    | map {
        [
            it[2], // index
            it[0], // input path
            it[1] // coarse result
        ]
    } \
    | join (indexed_name) \
    | map {
        def coarse_res_file = file(it[2])
        // get the acquisition output knowing that coarse results are generated in a 'aff' subdir
        def output_dir = coarse_res_file.parent.parent
        [
            it[0], // index
            it[3], // name
            it[1], // input path
            it[2], // coarse result
            output_dir
        ]
    }
}

def get_moving_results_dir(moving_output_dir, fixed_name, moving_name) {
    return "${moving_output_dir}/${moving_name}-to-${fixed_name}"
}
