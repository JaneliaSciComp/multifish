include {
    apply_transform;
} from '../processes/registration'

workflow warp_spots {

    take:
    fixed
    fixed_subpath
    moving
    moving_subpath
    warped_spots_txmpath
    warped_spots_path
    points_path

    main:
    done = apply_transform(
        fixed,
        fixed_subpath,
        moving,
        moving_subpath,
        warped_spots_txmpath,
        warped_spots_path,
        points_path,
        params.warp_spots_cpus,
        params.warp_spots_memory)
    
    emit:
    done
} // [ warped_spots_path, fixed  subpath]
