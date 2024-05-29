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
    pretty;
} from './utils'


// Register one "moving" round acquisition to a "fixed" round.
// 
// The first channel passed into this workflow is a set of tuples, 
// each one defining a registration task:
//  0 - fixed acq name
//  1 - fixed image
//  2 - moving acq name
//  3 - moving image
//  4 - output dir
//
workflow registration {
    take:
    registrations
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
    def normalized_fixed_input_dir = registrations.map { it[1] }
    def normalized_moving_input_dir = registrations.map { it[3] }
    def normalized_output_dir = registrations.map { it[4] }

    registrations.subscribe { log.debug "Registration: ${pretty(it)}}" }

    // prepare tile coordinates
    def tile_cut_res = cut_tiles(
        registrations.map { it[1] },
        "/${reg_ch}/${deformation_scale}",
        normalized_output_dir.map { "${it}/tiles" },
        xy_stride,
        xy_overlap,
        z_stride,
        z_overlap
    ) // fixed, tiles_list

    // expand and index tiles
    def tiles_with_inputs = tile_cut_res
    | flatMap {
        def (tile_input, tiles) = it
        tiles.tokenize().collect { tile_dirname ->
            def tile_dir = file(tile_dirname)
            [ "${tile_dir.parent.parent}", tile_input, tile_dirname ]
        }
    } // [ output_dir, tile_input, tile_dir ]

    tiles_with_inputs.subscribe { log.debug "Tile data for local registration: $it" }

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
    ) // [ ransac_affine_output, scale_path ]

    aff_scale_affine_results.subscribe { log.debug "Affine results at affine scale: $it" }

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
    ) // [ ransac_affine_output, scale_path ] - expect ransac_affine output to be <outputdir>/aff/ransac_affine

    def_scale_affine_results.subscribe { log.debug "Affine results at deform scale: $it" }

    // get fixed spots per tile
    def fixed_spots_results_per_tile = fixed_spots(
        tiles_with_inputs.map { it[1] }, //  image input for the tile
        "/${reg_ch}/${affine_scale}",
        tiles_with_inputs.map { it[2] }, // tile dir
        'fixed_spots.pkl',
        spots_cc_radius,
        spots_spot_number
    ) // [ fixed, tile_dir, fixed_pkl_path ]

    // combine the results at affine scale with the ccorresponding tiles
    // to find the correspondence we use the index in the input and output channels
    def moving_spots_inputs = aff_scale_affine_results
    | map {
        def (ransac_affine_output, ransac_affine_scale) = it
        def ar = [ "${file(ransac_affine_output).parent.parent}", ransac_affine_output, ransac_affine_scale ]
        log.debug "Affine result to combine with tiles: ${pretty(ar)}"
        ar
    }
    | combine(tiles_with_inputs, by:0) // // [ output_dir, ransac_affine, scale_path, fixed_input, tile_dir ]

    moving_spots_inputs.subscribe { log.debug "Moving spots input: $it" }

    // get moving spots per tile taking as input the output of the coarse affined at affine scale
    def moving_spots_results_per_tile = moving_spots(
        moving_spots_inputs.map { it[1] }, // input is the ransac_affine
        "/${reg_ch}/${affine_scale}",
        moving_spots_inputs.map { it[it.size-1] }, // tile dir
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
    def interpolated_results = tile_ransac_results
    | map {
        def tile_dir = file(it[0])
        return [ "${tile_dir.parent}", it[0]] // [ tiles_dir, tile_transform_matrix ]
    }
    | groupTuple // wait for ransac to complete for all
    | map {
        log.debug "Interpolate ${it[0]}"
        it[0]
    }
    | interpolate_affines
    | map {
        log.debug "Interpolated result: $it"
        [ it ]
    } // [ tiles_dir ]

    // prepare deform inputs - we combine the tile inputs
    // with interpolated results to guarantee the deform 
    // is not started before interpolation step is done
    def deform_inputs = tiles_with_inputs
    | map {
        def tile_path = file(it[2])
        // [ <tile_parent_dir>, <output_dir>, <tile_input>, <tile_path> ]
        [ "${tile_path.parent}", it[0], it[1], it[2] ]
    }
    | combine(interpolated_results, by:0)
    | map {
        def (tiles_dir, current_registration_output, tile_fixed_input, tile) = it
        def r = [
            "${current_registration_output}/aff/ransac_affine",
            tile_fixed_input,
            tile
        ]
        log.debug "Extended interpolated result: ${pretty(r)}"
        return r
    }
    | combine(def_scale_affine_results, by:0) // [ ransac_affine, tile_fixed_input, tile, ransac_def_scale ]

    deform_inputs.subscribe { log.debug "Deform input: ${pretty(it)}" }

    // run the deformation
    def deform_results = deform(
        deform_inputs.map { it[2] }, // tile path
        deform_inputs.map { it[1] }, // fixed image -> tile input
        "/${reg_ch}/${deformation_scale}",
        deform_inputs.map { it[0] }, // affine moving coarse ransac results at deform scale
        "/${reg_ch}/${deformation_scale}",
        deform_iterations,
        deform_auto_mask
    )
    | map {
        // [ <tile>, <tile_input>, <deform_output> ]
        def tile_dir = file(it[0])
        def reg_output = "${tile_dir.parent.parent}"
        def aff_matrix = "${reg_output}/aff/ransac_affine.mat"
        def r = [ it[0], it[1],  reg_output, aff_matrix]
        log.debug "Deform result: ${pretty(r)}"
        return r
    }
    | groupTuple(by: [1,2,3]) // wait for all deform to complete
    | flatMap {
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

    // Run stitching once deformation is done for all tiles.
    //
    // This generates the complete transform mapping coordinates from the moving image to coordinates 
    // in the fixed image as a displacement vector field. For each voxel we need to store a vector of 
    // 3 numbers. For these N5 transforms, c0, c1, and c2 are the 3 components of this vector field – 
    // c0 contains a scalar field of displacements along the first axis, c1 is a scalar field of 
    // displacements along the second axis and so on.
    //
    // This can be a bit confusing because the data N5 files use the same nomenclature to mean something 
    // else, c0 == channel 0. For transforms you can think of c0 == component 0.
    def stitch_results = stitch(
        deform_results.map { it[0] }, // tile
        xy_overlap,
        z_overlap,
        deform_results.map { it[1] }, //  fixed image path
        "/${reg_ch}/${deformation_scale}",
        deform_results.map { it[3] }, // coarse ransac transformation matrix -> ransac_affine.mat
        deform_results.map { it[2] }, // output directory
        "/${deformation_scale}"
    )
    // tuples like this:
    //  0 - tile dir (LHA3_R5_small-to-LHA3_R3_small/tiles/4)
    //  1 - fixed image (LHA3_R3_small/stitching/export.n5)
    //  2 - output dir (LHA3_R5_small-to-LHA3_R3_small)
    //  3 - transform dir (LHA3_R5_small-to-LHA3_R3_small/transform)
    //  4 - invtransform dir (LHA3_R5_small-to-LHA3_R3_small/invtransform)
    stitch_results.subscribe { log.debug "Stitch result: ${pretty(it)}" }

    // set up a lookup channel that maps output dir to moving image dir 
    // e.g. [LHA3_R5_small-to-LHA3_R3_small, LHA3_R5_small/stitching/export.n5]
    // so that we can correlate the stitch results back to the moving image
    def output_to_moving_dir = registrations.map { 
        [ it[4], it[3] ]
    }

    // for final transformation wait until all tiles are stitched
    // and combine the results with the warped_channels
    def final_transform_inputs = stitch_results
    | groupTuple(by: [1,2,3,4]) // wait for all stitches to complete
    | map { // put output dir first and discard the tile dirs
        [ it[2], it[1], it[3], it[4] ]
    }
    | join(output_to_moving_dir, by:0)
    | flatMap { stitch_res ->
        // tuples like this:
        //  0 - output dir (LHA3_R5_small-to-LHA3_R3_small)
        //  1 - fixed image (LHA3_R3_small/stitching/export.n5)
        //  2 - transform (LHA3_R5_small-to-LHA3_R3_small/transform)
        //  3 - invtransform (LHA3_R5_small-to-LHA3_R3_small/invtransform)
        //  4 - moving image (LHA3_R5_small/stitching/export.n5)
        log.debug "Combined stitched result: ${pretty(stitch_res)}"

        def fixed_image = stitch_res[1]
        def moving_image = stitch_res[4]
        def transform_dir = file(stitch_res[2])
        def warp_dir = "${transform_dir.parent}/warped"

        warped_channels.collect { warped_ch ->
            def r = [
                fixed_image,
                "/${warped_ch}/${deformation_scale}",
                moving_image,
                "/${warped_ch}/${deformation_scale}",
                transform_dir, // this is the transform dir as a file type
                warp_dir,
            ]
            log.debug "Create warp input for channel $warped_ch: ${pretty(r)}"
            r
        }
    }
    // tuples like this:
    //  0 - fixed image
    //  1 - fixed image subpath
    //  2 - moving image
    //  3 - moving image subpath
    //  4 - transform dir
    //  5 - warped output dir
    final_transform_inputs.subscribe { log.debug "Final warp input: ${pretty(it)}" }

    // run the final transformation and generate the warped image
    def final_transform_res = final_transform(
        final_transform_inputs.map { it[0] },
        final_transform_inputs.map { it[1] },
        final_transform_inputs.map { it[2] },
        final_transform_inputs.map { it[3] },
        final_transform_inputs.map { it[4] },
        final_transform_inputs.map { it[5] }
    )
    final_transform_res.subscribe { log.debug "Final warp result: ${pretty(it)}" }

    def registration_res = final_transform_res
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
            log.debug "Registration result: ${pretty(r)}"
            r
        }
    } // [ <fixed>, <fixed_subpath>, <moving>, <moving_subpath>, <direct_transform>, <inv_transform>, <warped_path> ]

    emit:
    done = registration_res
}
