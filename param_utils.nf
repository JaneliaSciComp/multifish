def default_mf_params() {
    airlocalize_default_params = '/app/airlocalize/params/air_localize_default_params.txt'
    spot_extraction_xy_stride = 2048
    spot_extraction_z_stride = 1024
    spot_extraction_xy_overlap = (int) (0.05 * spot_extraction_xy_stride)
    spot_extraction_z_overlap = (int) (0.05 * spot_extraction_z_stride)

    [
        mfrepo: 'registry.int.janelia.org/janeliascicomp',
        stitching_app: 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar',
        stitching_output: 'stitching',
        resolution: '0.23,0.23,0.42',
        axis: '-x,y,z',
        channels: 'c0,c1,c2,c3',
        block_size: '128,128,64',
        registration_channel: '2',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        blur_sigma: '2',
        spot_extraction_output: 'spots',
        scale_4_spot_extraction: 's0',
        spot_extraction_xy_stride: spot_extraction_xy_stride,
        spot_extraction_xy_overlap: spot_extraction_xy_overlap,
        spot_extraction_z_stride: spot_extraction_z_stride,
        spot_extraction_z_overlap: spot_extraction_z_overlap,
        air_localize_channel_params: "${airlocalize_default_params},${airlocalize_default_params},${airlocalize_default_params},${airlocalize_default_params}"
    ]
}
