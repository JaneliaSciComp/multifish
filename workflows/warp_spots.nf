include {
    warp_spots as bigstream_warp_spots;
} from './bigstream_warp_spots'

include {
    warp_spots as legacy_warp_spots;
} from './legacy_warp_spots'

workflow warp_spots {

    take:
    warp_inputs // [fixed, fixed_subpath, moving, moving_subpath, transform_path, transform_subpath, warped_spots_path, input_spots_path]

    main:
    if (params.use_bigstream) {
        done = bigstream_warp_spots(warp_inputs)
    } else {
        done = legacy_warp_spots(warp_inputs)
    }

    emit:
    done
} // [ warped_spots_path, fixed  subpath]
