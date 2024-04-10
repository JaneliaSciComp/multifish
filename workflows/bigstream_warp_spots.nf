include {
    get_bigstream_params;
} from './bigstream_utils'

all_bigstream_params = get_bigstream_params(params)

include {
    BIGSTREAM_TRANSFORMCOORDS;
} from '../modules/janelia/bigstream/transformcoords/main' addParams(all_bigstream_params)

workflow warp_spots {

    take:
    warp_inputs // [fixed, fixed_subpath,
                //  moving, moving_subpath,
                //  transform_path, transform_subpath,
                //  warped_spots_path,
                //  input_spots_path]

    main:
    def bigstream_warp_inputs = warp_inputs
    | map {
        def (fixed, fixed_subpath,
             moving, moving_subpath,
             transform, transform_subpath,
             warped_coords_path,
             coords_path) = it
        def fixed_acq_name = file(fixed).parent.name
        def moving_acq_name = file(moving).parent.name
        def coords_file = file(coords_path)
        def warped_coords_file = file(warped_coords_path)

        def meta = [
            id: "${fixed_acq_name}-${moving_acq_name} - ${coords_file.name}",
        ]

        def coords_data = [
            meta,
            coords_path,
            warped_coords_file.parent,
            warped_coords_file.name,
        ]
        def r = [
            coords_data,
            [
                fixed, fixed_subpath,
            ],
            [
                '',  // resolution - we'll get it from the fix volume
                '',  // downsampling factors  - we'll get it from the fix volume
            ],
            [], // affine_transforms
            [
                transform,
                transform_subpath,
            ],
            [
                '', // dask_scheduler (none)
                [], // dask_config (none)
            ]
        ]
        log.debug "Bigstream warp spots input $it -> $r"
        r
    }
    BIGSTREAM_TRANSFORMCOORDS(
        bigstream_warp_inputs.map { it[0] },
        bigstream_warp_inputs.map { it[1] },
        bigstream_warp_inputs.map { it[2] },
        bigstream_warp_inputs.map { it[3] },
        bigstream_warp_inputs.map { it[4] },
        bigstream_warp_inputs.map { it[5] },
        params.warp_spots_cpus,
        params.warp_spots_memory,
    )

    def bigstream_warp_results = BIGSTREAM_TRANSFORMCOORDS.out.results
    | join(BIGSTREAM_TRANSFORMCOORDS.out.source, by:0)
    | map {
        def (meta, coords, warped_coords,
             coords_volume, coords_volume_subpath) = it
        def r = [
            warped_coords,
            coords_volume,
            coords_volume_subpath,
        ]
        log.debug "Completed warp spots: $it -> $r"
        r
    }
    
    emit:
    done = bigstream_warp_results
} // [ warped_spots_path, fixed  subpath]
