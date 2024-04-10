include {
    apply_transform;
} from '../processes/registration'

workflow warp_spots {

    take:
    warp_inputs // [fixed, fixed_subpath, moving, moving_subpath, transform_path, transform_subpath, warped_spots_path, input_spots_path]

    main:
    done = apply_transform(
        warp_inputs.map { it[0] }, // fixed
        warp_inputs.map { it[1] }, // fixed_subpath
        warp_inputs.map { it[2] }, // moving
        warp_inputs.map { it[3] }, // moving_subpath
        warp_inputs.map { it[4] }, // transform_path (transform_subpath not used)
        warp_inputs.map { it[6] }, // warped_spots_path
        warp_inputs.map { it[7] }, // points_path
        params.warp_spots_cpus,
        "${params.warp_spots_memory} GB")

    emit:
    done
} // [ warped_spots_path, fixed  subpath]
