include {
    get_bigstream_params;
} from './bigstream_utils'

all_bigstream_params = get_bigstream_params(params)

include {
    TRANSFORM_COORDS;
} from '../external-modules/bigstream/subworkflows/transform-coords' addParams(all_bigstream_params)

workflow warp_spots {

    take:
    warp_inputs // [fixed, fixed_subpath, moving, moving_subpath, transform_path, warped_spots_path, input_spots_path]

    main:
    def bigstream_warp_inputs = warp_inputs
    | map {
        def (fixed, fixed_subpath,
             moving, moving_subpath,
             transform,
             warped_coords_path,
             coords_path) = it
        return [
            [
                coords_path,
                warped_coords_path,
                '', // pixel resolution
                '', // downsampling
                moving,
                moving_subpath,
            ],
            [
                '', // affine (none)
                transform,
                '', // transform subpath
            ]
        ]
    }
    def bigstream_warp_results = TRANSFORM_COORDS(
        bigstream_warp_inputs.map { it[0] },
        bigstream_warp_inputs.map { it[1] }
    )
    | map {
        def (coords, warped_coords,
             pixel_resoultion, downsampling,
             coords_volume, coords_volume_dataset)) = it
        def r = [
            warped_coords,
            coords_volume,
            coords_volume_dataset,
        ]
        log.debug "Completed warp spots: $it -> $r"
        r
    }
    
    emit:
    done = bigstream_warp_results
} // [ warped_spots_path, fixed  subpath]
