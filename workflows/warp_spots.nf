include {
  apply_transform;
} from '../processes/registration' addParams(lsf_opts: params.lsf_opts, 
                                             registration_container: params.registration_container)

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
        1)
    
    emit:
    done
}
