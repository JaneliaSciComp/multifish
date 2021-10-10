def default_mf_params() {
    def multifish_container_repo = 'multifish'
    def default_airlocalize_params = '/app/airlocalize/params/air_localize_default_params.txt'

    [
        mfrepo: multifish_container_repo,
        stitching_container: '',
        spot_extraction_container: '',
        segmentation_container: '',
        registration_container: '',
        spots_assignment_container: '',

        acq_names: '', // this is the default parameter for all acquisitions that must be processed
                       // should only be used when all steps must be performed for all acquisions
        ref_acq: '', // reference image for registration and/or segmentation
        shared_work_dir: '',
        //shared_scratch_dir: "$workDir/scratch", // currently not used
        local_scratch_dir: "\$PROCESS_DIR",
        data_dir: '',
        output_dir: '',
        publish_dir: '',
        skip: '', // do not skip anything by default

        // download params
        downloader_container: 'multifish/downloader:1.1.0',
        data_manifest: '',
        verify_md5: 'true',

        // stitching params
        spark_container_repo: multifish_container_repo,
        spark_container_name: 'stitching',
        spark_container_version: '1.0.0',
        stitching_app: '/app/app.jar',
        stitching_output: 'stitching',
        resolution: '0.23,0.23,0.42',
        axis: '-x,y,z',
        channels: 'c0,c1,c2,c3',
        stitching_block_size: '128,128,64',
        retile_z_size: '64',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        stitching_blur_sigma: '2',
        stitching_czi_pattern: '', // A suffix pattern that is applied to acq_names when creating CZI names e.g. "_V%02d"
        workers: 4,
        worker_cores: 4,
        gb_per_core: 4,
        driver_memory: '15g',
        wait_for_spark_timeout_seconds: 3600,
        sleep_between_timeout_checks_seconds: 2,

        dapi_channel: 'c2', // DAPI channel used to drive both the segmentation and the registration
        ref_acq: '', // this is the default parameter for the fixed round and 
                                // should be used only when all steps that require a fixed round must be done

        // spot extraction params
        spot_extraction_output: 'spots',
        spot_extraction_scale: 's0',
        spot_extraction_xy_stride: 0, // use the default defined by spot_extraction_xy_stride_param
        spot_extraction_xy_overlap: 0, // use the default defined by spot_extraction_xy_overlap_param
        spot_extraction_z_stride: 0, // use the default defined by spot_extraction_z_stride_param
        spot_extraction_z_overlap: 0, // use the default defined by spot_extraction_z_overlap_param
        bleed_channel: 'c3',
        default_airlocalize_params: default_airlocalize_params,
        per_channel_air_localize_params: ",,,",
        spot_extraction_cpus: 1,
        spot_extraction_memory: '2 G',

        // segmentation params
        segmentation_output: 'segmentation',
        segmentation_model_dir: "${projectDir}/external-modules/segmentation/model/starfinity",
        segmentation_scale: 's2',
        segmentation_cpus: 3, // it needs at least 3 cpus for Janelia cluster config because of memory requirements
        segmentation_memory: '45 G',

        // registration params
        registration_fixed_output: 'fixed',
        registration_output: 'registration',
        aff_scale: 's3', // the scale level for affine alignments
        def_scale: "s2", // the scale level for deformable alignments
        registration_xy_stride: 0, // use the default defined by registration_xy_stride_param - must be a power of 2
        registration_xy_overlap: 0, // use the default defined by registration_xy_overlap_param
        registration_z_stride: 0, // use the default defined by registration_z_stride_param - must be a power of 2
        registration_z_overlap: 0, // use the default defined by registration_z_overlap_param
        spots_cc_radius: '8',
        spots_spot_number: '2000',
        // ransac params
        ransac_cc_cutoff: '0.9',
        ransac_dist_threshold: '2.5',
        // deformation parameters
        deform_iterations: '500x200x25x1',
        deform_auto_mask: '0',
        // compute resources
        ransac_cpus: 1,
        ransac_memory: '1 G',
        spots_cpus: 1,
        spots_memory: '2 G',
        interpolate_cpus: 1,
        interpolate_memory: '1 G',
        coarse_spots_cpus: 1,
        coarse_spots_memory: '2 G',
        aff_scale_transform_cpus: 1, // cores for affine scale transforms
        aff_scale_transform_memory: '15 G',
        def_scale_transform_cpus: 8, // cores for deformable scale transforms
        def_scale_transform_memory: '80 G',
        deform_cpus: 1,
        deform_memory: '10 G',
        registration_stitch_cpus: 2,
        registration_stitch_memory: '20 G',
        registration_transform_cpus: 12,
        registration_transform_memory: '80 G',

        // warp spots parameters
        warp_spots_cpus: 2,
        warp_spots_memory: '30 G',

        // intensity measurement parameters
        measure_intensities_output: 'intensities',
        measure_intensities_cpus: 1,

        // spot assignment parameters
        assign_spots_output: 'assignments',
        assign_spots_cpus: 1,
    ]
}

def set_derived_defaults(mf_params, user_params) {
    if (mf_params.shared_work_dir) {
        if (!user_params.containsKey('data_dir')) {
            mf_params.data_dir = "${mf_params.shared_work_dir}/inputs"
        }
        if (!user_params.containsKey('output_dir')) {
            mf_params.output_dir = "${mf_params.shared_work_dir}/outputs"
        }
        if (!user_params.containsKey('segmentation_model_dir')) {
            mf_params.segmentation_model_dir = "${mf_params.shared_work_dir}/inputs/model/starfinity"
        }
        if (!user_params.containsKey('spark_work_dir')) {
            mf_params.spark_work_dir = "${mf_params.shared_work_dir}/spark"
        }
        if (!user_params.containsKey('singularity_cache_dir')) {
            mf_params.singularity_cache_dir = "${mf_params.shared_work_dir}/singularity"
        }
    }
    mf_params
}

def get_value_or_default(Map ps, String param, String default_value) {
    if (ps[param])
        ps[param]
    else
        default_value
}

def get_list_or_default(Map ps, String param, List default_list) {
    def value
    if (ps[param])
        value = ps[param]
    else
        value = null
    return value
        ? value.tokenize(',').collect { it.trim() }
        : default_list
}

def stitching_container_param(Map ps) {
    def stitching_container = ps.stitching_container
    if (!stitching_container)
        "${ps.mfrepo}/stitching:1.0.0"
    else
        stitching_container
}

def spot_extraction_container_param(Map ps) {
    def spot_extraction_container = ps.spot_extraction_container
    if (!spot_extraction_container)
        "${ps.mfrepo}/spot_extraction:1.0.3"
    else
        spot_extraction_container
}

def segmentation_container_param(Map ps) {
    def segmentation_container = ps.segmentation_container
    if (!segmentation_container)
        "${ps.mfrepo}/segmentation:1.0.0"
    else
        segmentation_container
}

def registration_container_param(Map ps) {
    def registration_container = ps.registration_container
    if (!registration_container)
        "${ps.mfrepo}/registration:1.2.0"
    else
        registration_container
}

def spots_assignment_container_param(Map ps) {
    def spots_assignment_container = ps.spots_assignment_container
    if (!spots_assignment_container)
        "${ps.mfrepo}/spot_assignment:1.2.0"
    else
        spots_assignment_container
}

/**
 * Get the stitching ref channel or if not specified use dapi_channel.
 * Also extracts only the numeric part from the channel since that's
 * how the stitching pipeline expects it.
 */
def stitching_ref_param(Map ps) {
    def stitching_ref = ps.stitching_ref
        ? ps.stitching_ref
        : ps.dapi_channel
    def ch_num_lookup = (stitching_ref =~ /(\d+)/)
    if (ch_num_lookup.find()) {
        ch_num_lookup[0][1]
    } else {
        ''
    }
}

def spot_extraction_xy_stride_param(Map ps) {
    def spot_extraction_xy_stride = ps.spot_extraction_xy_stride
    if (!spot_extraction_xy_stride) {
        return 1024
    } else {
        return spot_extraction_xy_stride
    }
}

def spot_extraction_xy_overlap_param(Map ps) {
    def spot_extraction_xy_overlap = ps.spot_extraction_xy_overlap
    if (!spot_extraction_xy_overlap) {
        spot_extraction_xy_overlap = (int) (0.05 * spot_extraction_xy_stride_param(ps))
        return spot_extraction_xy_overlap < 50 ?  50 : spot_extraction_xy_overlap
    } else {
        return spot_extraction_xy_overlap
    }
}

def spot_extraction_z_stride_param(Map ps) {
    def spot_extraction_z_stride = ps.spot_extraction_z_stride
    if (!spot_extraction_z_stride) {
        return 512
    } else {
        return spot_extraction_z_stride
    }
}

def spot_extraction_z_overlap_param(Map ps) {
    def spot_extraction_z_overlap = ps.spot_extraction_z_overlap
    if (!spot_extraction_z_overlap) {
        spot_extraction_z_overlap = (int) (0.05 * spot_extraction_z_stride_param(ps))
        return spot_extraction_z_overlap < 50 ?  50 : spot_extraction_z_overlap
    } else {
        return spot_extraction_z_overlap
    }
}

def registration_xy_stride_param(Map ps) {
    def registration_xy_stride = ps.registration_xy_stride
    if (!registration_xy_stride) {
        return 256
    } else {
        return registration_xy_stride
    }
}

def registration_xy_overlap_param(Map ps) {
    def registration_xy_overlap = ps.registration_xy_overlap
    if (!registration_xy_overlap) {
        return (int) (registration_xy_stride_param(ps) / 8)
    } else {
        return registration_xy_overlap
    }
}

def registration_z_stride_param(Map ps) {
    def registration_z_stride = ps.registration_z_stride
    if (!registration_z_stride) {
        return 256
    } else {
        return registration_z_stride
    }
}

def registration_z_overlap_param(Map ps) {
    def registration_z_overlap = ps.registration_z_overlap
    if (!registration_z_overlap) {
        return (int) (registration_z_stride_param(ps) / 8)
    } else {
        return registration_z_overlap
    }
}
