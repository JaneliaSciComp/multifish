include {
    apply_transform;
} from '../processes/registration'

include {
    collect_merged_points_files
} from '../processes/warp_spots'

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

workflow collect_merge_points {

    take:
    merged_points_path

    main:
    done = collect_merged_points_files(
        merged_points_path
    )
    | flatMap {
        def ( merged_points_dir, merged_points_files ) = it
        log.debug "Found ${merged_points_files} in ${merged_points_dir}"
        merged_points_files.tokenize(' ').collect { fn ->
            [ merged_points_dir, fn ]
        }
    }

    emit:
    done
}