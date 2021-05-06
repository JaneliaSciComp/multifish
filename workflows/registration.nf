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
} from './utils'

workflow registration {
    take:
    fixed_input_dir
    moving_input_dir
    output_dir
    reg_ch
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
    warped_channels

    main:
    // make sure the inputs are all strings
    def normalized_fixed_input_dir = fixed_input_dir.map { "$it" }
    def normalized_moving_input_dir = moving_input_dir.map { "$it" }
    def normalized_output_dir = output_dir.map { "$it" }

    // prepare tile coordinates
    def tile_cut_res = cut_tiles(
        normalized_fixed_input_dir,
        "/${reg_ch}/${deformation_scale}",
        normalized_output_dir.map { "${it}/tiles" },
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ) // fixed, tiles_list

    // expand and index tiles
    def tiles_with_inputs = index_channel(tile_cut_res[0])
    | join(index_channel(tile_cut_res[1]))
    | flatMap {
        def index = it[0]
        def tile_input = it[1]
        it[2].tokenize(' ').collect {
            [ index, tile_input, it ]
        }
    }

    // get fixed coarse spots
    def fixed_coarse_spots_results = fixed_coarse_spots(
        normalized_fixed_input_dir,
        "/${reg_ch}/${affine_scale}",
        normalized_output_dir.map { "${it}/aff" },
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [fixed, affdir, fixedpkl]

    // get moving coarse spots
    def moving_coarse_spots_results = moving_coarse_spots(
        normalized_moving_input_dir,
        "/${reg_ch}/${affine_scale}",
        normalized_output_dir.map { "${it}/aff" },
        'moving_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [moving, affdir, movingpkl]

    def coarse_ransac_inputs = fixed_coarse_spots_results.join(
        moving_coarse_spots_results,
        by:1 // join by coarse results output dir
    ) // [aff_output_dir, fixed_input, fixed_spots, moving_input, moving_spots]
    
    // compute transformation matrix (ransac_affine.mat)
    def coarse_ransac_results = coarse_ransac(
        coarse_ransac_inputs.map { it[2] }, // fixed spots
        coarse_ransac_inputs.map { it[4] }, // moving spots
        coarse_ransac_inputs.map { it[0] }, // output dir
        'ransac_affine.mat',
        ransac_cc_cutoff,
        ransac_dist_threshold
    ) | join(coarse_ransac_inputs) // [ aff_output_dir, ransac_affine_tx_matrix, fixed_input, fixed_spots, moving_input, moving_spots]

    // compute ransac_affine at affine scale
    def aff_scale_affine_results = apply_transform_at_aff_scale(
        coarse_ransac_results.map { it[2] }, // fixed input
        "/${reg_ch}/${affine_scale}",
        coarse_ransac_results.map { it[4] }, // moving input
        "/${reg_ch}/${affine_scale}",
        coarse_ransac_results.map { it[1] }, // transform matrix
        coarse_ransac_results.map { "${it[0]}/ransac_affine" },
        '', // no points path
        params.aff_scale_transform_cpus,
        params.aff_scale_transform_memory
    ) | map {
        def ransac_affine_output = file(it[0])
        // [ ransac_affine_output, output_dir, scale_path]
        def r = [ it[0], "${ransac_affine_output.parent.parent}", it[1] ]
        log.debug "Affine results at affine scale: $r"
        return r
    }

    // compute ransac_affine at deformation scale
    def def_scale_affine_results = apply_transform_at_def_scale(
        coarse_ransac_results.map { it[2] }, // fixed input
        "/${reg_ch}/${deformation_scale}",
        coarse_ransac_results.map { it[4] }, // moving input
        "/${reg_ch}/${deformation_scale}",
        coarse_ransac_results.map { it[1] }, // transform matrix
        coarse_ransac_results.map { "${it[0]}/ransac_affine" },
        '', // no points path
        params.def_scale_transform_cpus,
        params.def_scale_transform_memory
    ) | map {
        // expect ransac_affine output to be <outputdir>/aff/ransac_affine
        // so 2 parents up will give us the output dir
        def ransac_affine_output = file(it[0])
        // [ ransac_affine_output, output_dir, scale_path]
        def r = [ it[0], "${ransac_affine_output.parent.parent}", it[1] ]
        log.debug "Affine results at deform scale: $r"
        return r
    }
    
    // get fixed spots per tile
    def fixed_spots_results_per_tile = fixed_spots(
        tiles_with_inputs.map { it[1] }, //  image input for the tile
        "/${reg_ch}/${affine_scale}",
        tiles_with_inputs.map { it[2] }, // tile dir
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [ fixed, tile_dir, fixed_pkl_path ]

    def indexed_output = index_channel(normalized_output_dir)

    // combine the results at affine scale with the ccorresponding tiles
    // to find the correspondence we use the index in the input and output channels
    def indexed_moving_spots_inputs = aff_scale_affine_results
    | join(indexed_output, by:1) | map {
        // put the index as the first element in the tuple
        // [ index, output_dir, ransac_affine_output, scale_path ]
        def ar = [ it[it.size-1] ] + it[0..it.size-2]
        log.debug "Affine result to combine with tiles: $ar"
        ar
    } | combine(tiles_with_inputs, by:0) | map {
        // [ index, output_dir, ransac_affine, scale_path, fixed_input, tile_dir ]
        log.debug "Moving spots input: $it"
        it
    }

    // get moving spots per tile taking as input the output of the coarse affined at affine scale
    def moving_spots_results_per_tile = moving_spots(
        indexed_moving_spots_inputs.map { it[2] }, // input is the ransac_affine
        "/${reg_ch}/${affine_scale}",
        indexed_moving_spots_inputs.map { it[it.size-1] }, // tile dir
        'moving_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [ ransac_output, tile_dir, moving_pkl_path ]

    // merge fixed and moving ransac results using tile_directory as a key
    def per_tile_ransac_inputs = fixed_spots_results_per_tile.join(
        moving_spots_results_per_tile,
        by:1
    )

    // run ransac for each tile
    def tile_ransac_results = ransac_for_tile(
        per_tile_ransac_inputs.map { it[2] }, // fixed spots
        per_tile_ransac_inputs.map { it[4] }, // moving spots
        per_tile_ransac_inputs.map { it[0] }, // tile dir
        'ransac_affine.mat',
        ransac_cc_cutoff,
        ransac_dist_threshold
    ) // [ tile_dir, tile_transform_matrix  ]

    // interpolate tile ransac results
    def interpolated_results = tile_ransac_results | map {
        def tile_dir = file(it[0])
        return [ "${tile_dir.parent}", it[0]]
    } | groupTuple | map {
        log.debug "Interpolate ${it[0]}"
        it[0]
    } | interpolate_affines | map {
        log.debug "Interpolated result: $it"
        [ it ]
    }

    // prepare deform inputs - we combine the tile inputs
    // with interpolated results to guarantee the deform 
    // is not started before interpolation step is done
    def deform_inputs = tiles_with_inputs | map {
        def tile_path = file(it[2])
        // [ <tile_parent_dir>, <index>, <tile_input>, <tile_path> ]
        [ "${tile_path.parent}", it[0], it[1], it[2] ]
    } | combine(interpolated_results, by:0) | map {
        def tile_parent_dir = file(it[0])
        // [ <index>, <tile_input>, <tile_parent_dir>, <tile_path>, <ransac_output> ]
        def r = [ "${tile_parent_dir.parent}/aff/ransac_affine", it[1], it[2], it[0], it[3] ]
        log.debug "Extended interpolated result: $r"
        return r
    } | combine(def_scale_affine_results, by:0) | map {
        log.debug "Deform input: $it"
        return it
    }

    // run the deformation
    def deform_results = deform(
        deform_inputs.map { it[4] }, // tile path
        deform_inputs.map { it[2] }, // fixed image -> tile input
        "/${reg_ch}/${deformation_scale}",
        deform_inputs.map { it[0] }, // affine moving coarse ransac results at deform scale
        "/${reg_ch}/${deformation_scale}",
        deform_iterations,
        deform_auto_mask
    ) | map {
        // [ <tile>, <tile_input>, <deform_output> ]
        def tile_dir = file(it[0])
        def reg_output = "${tile_dir.parent.parent}"
        def aff_matrix = "${reg_output}/aff/ransac_affine.mat"
        def r = [ it[0], it[1],  reg_output, aff_matrix]
        log.debug "Deform result: $it -> $r"
        return r
    } | groupTuple(by: [1,2,3]) | flatMap {
        // the grouping and the reconstruction of the input
        // is done to guarantee the completeness of 
        // the deform  operation for all tiles
        def tile_input = it[1]
        def reg_output = it[2]
        def aff_matrix = it[3]
        it[0].collect { tile ->
            [ tile, tile_input, reg_output, aff_matrix ]
        }
    }

    // run stitching once deformation is done for all tiles
    def stitch_results = stitch(
        deform_results.map { it[0] }, // tile
        xy_overlap,
        z_overlap,
        deform_results.map { it[1] }, //  fixed image path
        "/${reg_ch}/${deformation_scale}",
        deform_results.map { it[3] }, // coarse ransac transformation matrix -> ransac_affine.mat
        deform_results.map { "${it[2]}/transform" }, // transform directory
        deform_results.map { "${it[2]}/invtransform" }, // inverse transform directory
        "/${deformation_scale}"
    )

    // for final transformation wait until all tiles are stitched
    // and combine the results with the warped_channels
    def final_transform_inputs = stitch_results
    | map {
        log.debug "Stitch result: $it"
        it
    }
    | groupTuple(by: [1,2,3,4,5])
    | combine(normalized_moving_input_dir)
    | flatMap { stitch_res ->
        log.debug "Combined stitched result: ${stitch_res}"
        def reference = stitch_res[1]
        def to_warp = stitch_res[6]
        def transform_dir = file(stitch_res[2])
        def warp_dir = "${transform_dir.parent}/warped"

        warped_channels.collect { warped_ch ->
            def r = [
                reference,
                "/${warped_ch}/${deformation_scale}",
                to_warp,
                "/${warped_ch}/${deformation_scale}",
                transform_dir, // this is the transform dir as a file type
                warp_dir,
            ]
            log.debug "Create warp input for channel $warped_ch: $r"
            r
        }
    }
    final_transform_inputs.subscribe { log.debug "Final warp input: $it" }

    // run the final transformation and generate the warped image
    def final_transform_res = final_transform(
        final_transform_inputs.map { it[0] },
        final_transform_inputs.map { it[1] },
        final_transform_inputs.map { it[2] },
        final_transform_inputs.map { it[3] },
        final_transform_inputs.map { it[4] },
        final_transform_inputs.map { it[5] }
    )
    final_transform_res.subscribe { log.debug "Final warp result: $it" }

    registration_res = final_transform_res
    | groupTuple(by: [0,2,4,5])
    | flatMap { final_tx_res ->
        def ref_subpath = final_tx_res[1]
        def mov_subpath = final_tx_res[3]
        // also include invtransform path in the result
        def txm_path = file(final_tx_res[4])
        def inv_transform = "${txm_path.parent}/invtransform"
        [ ref_subpath, mov_subpath ].transpose().collect { subpaths ->
            def r = [
                final_tx_res[0], // fixed
                subpaths[0], // fixed_subpath
                final_tx_res[2], // moving
                subpaths[1], // moving subpath
                final_tx_res[4], // dir transform
                inv_transform, // inv transform
                final_tx_res[5] // output
            ]
            log.debug "Registration result: $r"
            r
        }
    } // [ <fixed>, <fixed_subpath>, <moving>, <moving_subpath>, <direct_transform>, <inv_transform>, <warped_path> ]

    emit:
    registration_res
}
