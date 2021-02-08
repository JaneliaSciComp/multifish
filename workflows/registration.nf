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
    deform_iterations
    deform_auto_mask

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
        by:1 // join by coarse results output dir
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
        def r = [ it[0], "${ransac_affine_output.parent.parent}", it[1] ]
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
    ) | map {
        def ransac_affine_output = file(it[0])
        // [ ransac_affine_output, output_dir, scale_path]
        def r = [ it[0], "${ransac_affine_output.parent.parent}", it[1] ]
        println "Affine results at deform scale: $r"
        return r
    }
    
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
    | join(indexed_output, by:1) | map {
        // put the index as the first element in the tuple
        // [ index, output_dir, ransac_affine_output, scale_path ]
        def ar = [ it[it.size-1] ] + it[0..it.size-2]
        println "Affine result to combine with tiles: $ar"
        ar
    } | combine(tiles_with_inputs, by:0) | map {
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
        return [ "${tile_dir.parent}", it[1]]
    } | groupTuple | map {
        println "Interpolate ${it[0]}"
        it[0]
    } | interpolate_affines | map {
        println "Interpolated result: $it"
        [ it ]
    }

    def deform_inputs = tiles_with_inputs | map {
        def tile_path = file(it[2])
        // [ <tile_parent_dir>, <index>, <tile_input>, <tile_path> ]
        [ "${tile_path.parent}", it[0], it[1], it[2] ]
    } | combine(interpolated_results, by:0) | map {
        def tile_parent_dir = file(it[0])
        // [ <index>, <tile_input>, <tile_parent_dir>, <tile_path>, <ransac_output> ]
        def r = [ "${tile_parent_dir.parent}/aff/ransac_affine", it[1], it[2], it[0], it[3] ]
        println "Extended interpolated result: $r"
        return r
    } | combine(def_scale_affine_results, by:0) | map {
        println "Deform input: $it"
        return it
    }

    def deform_results = deform(
        deform_inputs.map { it[4] }, // tile path
        deform_inputs.map { it[2] }, // fixed image -> tile input
        "/${ch}/${deformation_scale}",
        deform_inputs.map { it[0] }, // affine moving coarse ransac results at deform scale
        "/${ch}/${deformation_scale}",
        deform_iterations,
        deform_auto_mask
    ) | map {
        // [ <tile>, <tile_input>, <deform_output> ]
        println "Deform result: $it"
        // [ <tile>, <tile_input> ]
        [ it[0], it[1] ]
    }

    def stitch_results = stitch(
        deform_results.map { it[0] }, // tile
        xy_overlap,
        z_overlap,
        deform_results.map { it[1] }, //  fixed image path
        "/${ch}/${deformation_scale}",
        coarse_ransac_results.map { it[1] }, // coarse ransac transformation matrix -> ransac_affine.mat
        output_dir.map { "${it}/transform" }, // transform directory
        output_dir.map { "${it}/invtransform" }, // inverse transform directory
        "/${deformation_scale}",
        params.stitch_registered_cpus
    ) | groupTuple(by:[1,2,3,4,5]) // group all tiles in one collection

    done = final_transform(
        stitch_results.map { it[1] },
        "/${ch}/${deformation_scale}",
        moving_input_dir,
        "/${ch}/${deformation_scale}",
        stitch_results.map { it[2] }, // stitch transform dir
        output_dir.map { "${it}/warped" }, // warped directory
        params.final_transform_cpus
    )

    emit:
    done
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
