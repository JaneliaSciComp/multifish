include {
    cut_tiles;
    run_airlocalize;
    merge_points;
} from '../processes/airlocalize' addParams(lsf_opts: params.lsf_opts, 
                                                airlocalize_container: params.airlocalize_container)

include {
    index_channel;
} from './utils'

workflow airlocalize {
    take:
    input_dir
    output_dir
    spot_channels
    scale
    dapi_channel
    bleedthrough_channels

    main:
    def tile_cut_res = cut_tiles(
        input_dir,
        dapi_channel,
        scale,
        output_dir.map { "${it}/tiles" },
        params.airlocalize_xy_stride,
        params.airlocalize_xy_overlap,
        params.airlocalize_z_stride,
        params.airlocalize_z_overlap
    )

    def tiles_with_inputs = tile_cut_res
    | flatMap {
        def (tile_input, tiles) = it
        tiles.tokenize(' ').collect { tile ->
            [ tile_input, tile ]
        }
    }

    def per_channel_air_localize_params = [
        params.channels?.split(','),
        params.per_channel_air_localize_params?.split(',', -1)
    ].transpose()
    .inject([:]) { a, b ->
        def ch = b[0]
        airlocalize_params = b[1] == null || b[1] == ''
            ? params.default_airlocalize_params
            : b[1]
        a[ch] =  airlocalize_params
        return a 
    }

    def airlocalize_inputs = tiles_with_inputs
    | combine(spot_channels)
    | map {
        def (tile_input, tile_dir, ch) = it
        def dapi_correction = bleedthrough_channels.contains(ch)
                ? "/${dapi_channel}/${scale}"
                : ''
        // return a tuple with all required arguments for airlocalize
        def airlocalize_args = [
            tile_input,
            ch,
            scale,
            "${tile_dir}/coords.txt",
            per_channel_air_localize_params[ch],
            tile_dir,
            "_${ch}.txt",
            dapi_correction
        ]
        log.debug "Create airlocalize args: $it -> ${airlocalize_args}"
        return airlocalize_args
    }

    def airlocalize_results = run_airlocalize(
        airlocalize_inputs.map { it[0] },
        airlocalize_inputs.map { it[1] },
        airlocalize_inputs.map { it[2] },
        airlocalize_inputs.map { it[3] },
        airlocalize_inputs.map { it[4] },
        airlocalize_inputs.map { it[5] },
        airlocalize_inputs.map { it[6] },
        airlocalize_inputs.map { it[7] }
    ) | map {
        def tile_dir = new File(it[1])
        [
            it[0], // input image path
            tile_dir.parent, // directory that contains all tiles
            it[1], // tile dir
            it[2] // channel
        ]
    }
    
    groupTuple(by: [0, 1])

    def merge_points_inputs = airlocalize_results | groupTuple(by: [0, 1, 3]) | map {
        def tile_input = it[0]
        def tiles_dir = new File(it[1])
        def tiles = it[2]
        def ch = it[3]
        def merge_points_args = [
            tile_input,
            ch,
            scale,
            tiles_dir,
            params.airlocalize_xy_overlap,
            params.airlocalize_z_overlap,
            tiles_dir.parent
        ]
        log.debug "Merge ${tiles} using ${merge_points_args}"
        return merge_points_args
    }

    merge_points_results = merge_points(
        merge_points_inputs.map { it[0] }, // image path
        merge_points_inputs.map { it[1] }, // channel
        merge_points_inputs.map { it[2] }, // spot extraction scale
        merge_points_inputs.map { it[3] }, // tiles dir
        merge_points_inputs.map { it[4] }, // xy overlap
        merge_points_inputs.map { it[5] }, // z overlap
        merge_points_inputs.map { it[6] } // merged points output dir
    ) // [ <input_image>, <ch>, <scale>, <spots_microns>, <spots_voxels> ]

    emit:
    merge_points_results
}
