include {
    collect_merged_points_files
} from '../processes/warp_spots'

workflow collect_merge_points {

    take:
    merged_points_path

    main:
    done = collect_merged_points_files(
        merged_points_path
    )
    | filter { it[0] != it[1] }
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