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
        def coarse_input = it + get_moving_results_dir(it[9], it[1], it[6])
        println "Coarse ransac input: ${coarse_input}"
        return coarse_input
    }

    // compute transformation matrix (ransac_affine.mat)
    def coarse_ransac_results = coarse_ransac(
        coarse_ransac_inputs.map { it[3] }, // fixed spots
        coarse_ransac_inputs.map { it[8] }, // moving spots
        coarse_ransac_inputs.map { "${it[10]}/aff" },
        'ransac_affine.mat', \
        ransac_cc_cutoff,
        ransac_dist_threshold
    )

    def indexed_coarse_ransac_results = coarse_ransac_inputs | map {
         // prepend the ransac result in order to join with the result
        [ "${it[10]}/aff/ransac_affine.mat" ] + it
    } | join (coarse_ransac_results) | map {
        println "Indexed coarse result: $it"
        it
    }

    // compute ransac_affine at affine scale
    def aff_scale_affine_results = apply_transform_at_aff_scale(
        indexed_coarse_ransac_results.map { it[3] },
        "/${ch}/${affine_scale}",
        indexed_coarse_ransac_results.map { it[8] },
        "/${ch}/${affine_scale}",
        indexed_coarse_ransac_results.map { it[0] }, // transform matrix was the join key
        indexed_coarse_ransac_results.map { "${it[11]}/aff/ransac_affine" },
        params.aff_scale_transform_cpus
    )

    // compute ransac_affine at deformation scale
    def def_scale_affine_results = apply_transform_at_def_scale(
        indexed_coarse_ransac_results.map { it[3] },
        "/${ch}/${deformation_scale}",
        indexed_coarse_ransac_results.map { it[8] },
        "/${ch}/${deformation_scale}",
        indexed_coarse_ransac_results.map { it[0] }, // transform matrix was the join key
        indexed_coarse_ransac_results.map { "${it[11]}/aff/ransac_affine" },
        params.def_scale_transform_cpus
    )

    // get fixed spots per tile
    def fixed_spots_results = fixed_spots(
        tiles_with_inputs.map { it[0] }, //  image input for the tile
        "/${ch}/${affine_scale}",
        tiles_with_inputs.map { it[1] }, // coord dir (tile dir)
        tiles_with_inputs.map { it[1] }, // put results  in the tile dir 
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) | groupTuple // group  results by input path

    def indexed_aff_scale_affine_results = coarse_ransac_inputs | map {
         // prepend the transform result in order to join with the affine result
        [ "${it[10]}/aff/ransac_affine" ] + it
    } | join (aff_scale_affine_results) | map {
        // prepend the fixed input path
        [ it[3] ] + it
    } |  combine(tiles_with_inputs, by:0) | map {
        println "Indexed affine  result: $it"
        it
    }

    // get moving spots per tile taking as input the output of the coarse affined at affine scale
    def moving_spots_results = moving_spots(
        aff_scale_affine_results.map { it[1]] }, // image input for the tile
        "/${ch}/${affine_scale}",
        indexed_aff_scale_affine_results.map { it[it.size-1] }, // coord dir
        indexed_aff_scale_affine_results.map {
            def tile_path = file(it[it.size-1])
            "${it[11]}/tiles/${tile_path.name}"
        }, // output  results
        'moving_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) | groupTuple // group  results by input path

    emit:
    done = moving_spots_results
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
