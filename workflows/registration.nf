include {
  cut_tiles;
  coarse_spots as fixed_coarse_spots;
  coarse_spots as moving_coarse_spots;
  ransac as coarse_ransac;
  apply_transform as apply_transform_at_aff_scale;
  apply_transform as apply_transform_at_def_scale;
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

workflow registration {
    take:
    fixed_input_dir
    moving_input_dir
    output_dir
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
        output_dir.map { "${it}/tiles" },
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    )

    def tiles_with_inputs = index_channel(tile_cut_res[0]) | join(index_channel(tile_cut_res[1])) | flatMap {
        def index = it[0]
        def tile_input = it[1]
        it[2].tokenize(' ').collect {
            [ index, tile_input, it ]
        }
    }

    // get fixed coarse spots
    def fixed_coarse_spots_results = fixed_coarse_spots(
        fixed_input_dir,
        "/${ch}/${affine_scale}",
        output_dir.map { "${it}/aff" },
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    )

    // get moving coarse spots
    def moving_coarse_spots_results = moving_coarse_spots(
        moving_input_dir,
        "/${ch}/${affine_scale}",
        output_dir.map { "${it}/aff" },
        'moving_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    )

    def coarse_ransac_inputs = fixed_coarse_spots_results.join(
        moving_coarse_spots_results,
        by:1
    ) // [aff_output_dir, fixed_input, fixed_spots, moving_input, moving_spots]
    
    // compute transformation matrix (ransac_affine.mat)
    def coarse_ransac_results = coarse_ransac(
        coarse_ransac_inputs.map { it[2] }, // fixed spots
        coarse_ransac_inputs.map { it[4] }, // moving spots
        coarse_ransac_inputs.map { it[0] }, // output dir
        'ransac_affine.mat', \
        ransac_cc_cutoff,
        ransac_dist_threshold
    ) | map {
        [ it[1], it[0] ] // [aff_output_dir, result_file]
    } | join(coarse_ransac_inputs) // [ aff_output_dir, ransac_affine_tx_matrix, fixed_input, fixed_spots, moving_input, moving_spots]

    // compute ransac_affine at affine scale
    def aff_scale_affine_results = apply_transform_at_aff_scale(
        coarse_ransac_results.map { it[2] }, // fixed input
        "/${ch}/${affine_scale}",
        coarse_ransac_results.map { it[4] }, // moving input
        "/${ch}/${affine_scale}",
        coarse_ransac_results.map { it[1] }, // transform matrix
        coarse_ransac_results.map { "${it[0]}/ransac_affine" },
        params.aff_scale_transform_cpus
    ) | map {
        def ransac_affine_output = file(it[0])
        // [ ransac_affine_output, output_dir, scale_path]
        def r = [ ransac_affine_output, ransac_affine_output.parent.parent, it[1] ]
        println "Affine results at affine scale: $r"
        return r
    }

    // compute ransac_affine at deformation scale
    def def_scale_affine_results = apply_transform_at_def_scale(
        coarse_ransac_results.map { it[2] }, // fixed input
        "/${ch}/${deformation_scale}",
        coarse_ransac_results.map { it[4] }, // moving input
        "/${ch}/${deformation_scale}",
        coarse_ransac_results.map { it[1] }, // transform matrix
        coarse_ransac_results.map { "${it[0]}/ransac_affine" },
        params.def_scale_transform_cpus
    ) // [ ransac_affine_output, scale_path]
    
    // get fixed spots per tile
    def fixed_spots_results_per_tile = fixed_spots(
        tiles_with_inputs.map { it[1] }, //  image input for the tile
        "/${ch}/${affine_scale}",
        tiles_with_inputs.map { it[2] }, // tile dir
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [ fixed, tile_dir, fixed_pkl_path ]

    def indexed_output = index_channel(output_dir)

    def indexed_moving_spots_inputs = aff_scale_affine_results \
    | join(indexed_output, by:1) \
    | map {
        // put the index as the first element in the tuple
        // [ index, output_dir, ransac_affine_output, scale_path ]
        [ it[it.size-1] ] + it[0..it.size-2]
    } \
    | combine(tiles_with_inputs, by:0) | map {
        // [ index, output_dir, ransac_affine, scale_path, fixed_input, tile_dir ]
        println "Moving spots input: $it"
        it
    }

    // get moving spots per tile taking as input the output of the coarse affined at affine scale
    def moving_spots_results_per_tile = moving_spots(
        indexed_moving_spots_inputs.map { it[2] }, // input is the ransac_affine
        "/${ch}/${affine_scale}",
        indexed_moving_spots_inputs.map { it[it.size-1] }, // tile dir
        'moving_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [ ransac_output, tile_dir, moving_pkl_path ]

    def per_tile_ransac_inputs = fixed_spots_results_per_tile.join(
        moving_spots_results_per_tile,
        by:1
    )

    def tile_ransac_results = ransac_for_tile(
        per_tile_ransac_inputs.map { it[2] }, // fixed spots
        per_tile_ransac_inputs.map { it[4] }, // moving spots
        per_tile_ransac_inputs.map { it[0] }, // tile dir
        'ransac_affine.mat',
        ransac_cc_cutoff,
        ransac_dist_threshold
    ) // [ tile_transform_matrix, tile_dir ]

    def interpolated_results = tile_ransac_results | map {
        def tile_dir = file(it[1])
        return [ tile_dir.parent, tile_dir]
    } \
    | groupTuple \
    | map { it[0] } \
    | interpolate_affines

    //  \
    // | map {
    //     def coarse_input = it + get_moving_results_dir(it[9], it[1], it[6])
    //     println "Coarse ransac input: ${coarse_input}"
    //     return coarse_input
    // }

    // def indexed_coarse_fixed_spots_results = index_coarse_results(
    //     fixed_input_dir, 
    // )

    // def indexed_coarse_moving_spots_results = index_coarse_results(
    //     moving_names,
    //     moving_input_dirs,
    //     )

    // // // create all combinations fixed coarse spots with moving coarse spots
    // def coarse_ransac_inputs = indexed_coarse_fixed_spots_results \
    // | combine(indexed_coarse_moving_spots_results) \
    // | map {
    //     def coarse_input = it + get_moving_results_dir(it[9], it[1], it[6])
    //     println "Coarse ransac input: ${coarse_input}"
    //     return coarse_input
    // }


    // def indexed_coarse_ransac_results = coarse_ransac_inputs | map {
    //      // prepend the ransac result in order to join with the result
    //     [ "${it[10]}/aff/ransac_affine.mat" ] + it
    // } | join (coarse_ransac_results) | map {
    //     println "Indexed coarse result: $it"
    //     it
    // }


/*

    def indexed_aff_scale_affine_results = coarse_ransac_inputs | map {
         // prepend the transform result in order to join with the affine result
        [ "${it[10]}/aff/ransac_affine" ] + it
    } | join (aff_scale_affine_results) | map {
        // prepend the fixed input path
        [ it[3] ] + it
    } |  combine(tiles_with_inputs, by:0) | map {
        println "Indexed affine result: $it"
        it
    }


    // compute transformation matrix (ransac_affine.mat) for each moving tile
    def indexed_moving_spots_results_per_tile = indexed_aff_scale_affine_results | map {
        def tile_path = file(it[it.size-1])
        [ it[1], "${it[11]}/tiles/${tile_path.name}/moving_spots.pkl"] + it
    } | join(moving_spots_results_per_tile.map { [ it[0], it[2], it[1] ] }, by:[0,1]) | map {
        // insert the fixed input and the tile coord location at the beginning
        def r = [ it[2], it[it.size-1] ] + it[0..it.size-2]
        println "Indexed moving spot result per tile  $r"
        return r
    }

    // cross join by fixed input and tile coord
    def tile_ransac_inputs = fixed_spots_results_per_tile \
    | combine(indexed_moving_spots_results_per_tile, by:[0, 1]) | map {
        println "Per tile ransac input $it"
        it
    }


*/
    emit:
    done = interpolated_results
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
