def default_mf_params() {
    def multifish_container_repo = 'public.ecr.aws/janeliascicomp/multifish'
    def default_airlocalize_params = '/app/airlocalize/params/air_localize_default_params.txt'

    [
        mfrepo: multifish_container_repo,
        stitching_container: '',
        airlocalize_container: '',
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
        downloader_container: multifish_container_repo+'/downloader:1.1.0',
        data_manifest: '',
        verify_md5: 'true',

        // stitching params
        spark_container_repo: multifish_container_repo,
        spark_container_name: 'stitching',
        spark_container_version: '1.1.0',
        stitching_app: '/app/app.jar',
        stitching_output: 'stitching',
        resolution: '0.23,0.23,0.42',
        axis: '-x,y,z',
        channels: 'c0,c1,c2,c3',
        stitching_block_size: '128,128,64',
        retile_z_size: 64,
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        stitching_blur_sigma: '2',
        stitching_czi_pattern: '', // A suffix pattern that is applied to acq_names when creating CZI names e.g. "_V%02d"
        flatfield_correction: true,
        with_fillBackground: true,
        workers: 6,
        worker_cores: 8,
        gb_per_core: 15,
        driver_memory: '2g',
        wait_for_spark_timeout_seconds: 7200,
        sleep_between_timeout_checks_seconds: 10,

        dapi_channel: 'c2', // DAPI channel used to drive both the segmentation and the registration
        ref_acq: '', // this is the default parameter for the fixed round and 
                     // should be used only when all steps that require a fixed round must be done
        bleed_channel: 'c3',

        // spot extraction params
        spot_extraction_output: 'spots',
        spot_extraction_scale: 's0',

        // Airlocalize params
        airlocalize_xy_stride: 0, // use the default defined by airlocalize_xy_stride_param
        airlocalize_xy_overlap: 0, // use the default defined by airlocalize_xy_overlap_param
        airlocalize_z_stride: 0, // use the default defined by airlocalize_z_stride_param
        airlocalize_z_overlap: 0, // use the default defined by airlocalize_z_overlap_param
        default_airlocalize_params: default_airlocalize_params,
        per_channel_air_localize_params: ",,,",
        airlocalize_cpus: 1,
        airlocalize_memory: '2 G',

        // RS-Fish params
        use_rsfish: false,
        rsfish_container_repo: multifish_container_repo,
        rsfish_container_name: 'rs_fish',
        rsfish_container_version: '1.0.2',
        rs_fish_app: '/app/app.jar',
        rsfish_workers: 6,
        rsfish_worker_cores: 8,
        rsfish_gb_per_core: 15,
        rsfish_driver_cores: 1,
        rsfish_driver_memory: '1g',
        rsfish_min: 0,
        rsfish_max: 4096,
        rsfish_anisotropy: 0.7,
        rsfish_sigma: 1.5,
        rsfish_threshold: 0.007,
        rsfish_background: 0,
        rsfish_intensity: 0,
        rsfish_params: '',
        // RS-Fish parameters adjustable per channel
        per_channel: [
            rsfish_min: '',
            rsfish_max: '',
            rsfish_anisotropy: '',
            rsfish_sigma: '',
            rsfish_threshold: '',
            rsfish_background: '',
            rsfish_intensity: '',
        ],

        // segmentation params
        segmentation_output: 'segmentation',
        segmentation_model_dir: "${projectDir}/external-modules/segmentation/model/starfinity",
        segmentation_scale: 's2',
        segmentation_cpus: 30,
        segmentation_memory: '220 G',

        // registration params
        registration_fixed_output: 'fixed',
        registration_output: 'registration',
        aff_scale: 's3', // the scale level for affine alignments
        def_scale: "s2", // the scale level for deformable alignments
        registration_xy_stride: 0, // use the default defined by registration_xy_stride_param - must be a power of 2
        registration_xy_overlap: 0, // use the default defined by registration_xy_overlap_param
        registration_z_stride: 0, // use the default defined by registration_z_stride_param - must be a power of 2
        registration_z_overlap: 0, // use the default defined by registration_z_overlap_param
        spots_cc_radius: 8,
        spots_spot_number: 2000,
        // ransac params
        ransac_cc_cutoff: 0.9,
        ransac_dist_threshold: 2.5,
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
        coarse_spots_memory: '8 G',
        aff_scale_transform_cpus: 1, // cores for affine scale transforms
        aff_scale_transform_memory: '15 G',
        def_scale_transform_cpus: 8, // cores for deformable scale transforms
        def_scale_transform_memory: '80 G',
        deform_cpus: 1,
        deform_memory: '4 G',
        registration_stitch_cpus: 2,
        registration_stitch_memory: '20 G',
        registration_transform_cpus: 12,
        registration_transform_memory: '120 G',

        // warp spots parameters
        warp_spots_cpus: 3,
        warp_spots_memory: '60 G',

        // intensity measurement parameters
        measure_intensities_output: 'intensities',
        measure_intensities_cpus: 1,
        measure_intensities_memory: '50 G',

        // spot assignment parameters
        assign_spots_output: 'assignments',
        assign_spots_cpus: 1,
        assign_spots_memory: '15 G',
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
    def source_value = ps[param]

    if (source_value == null) {
        return default_list
    } else if (source_value instanceof Boolean) {
        // most likely the parameter was set as '--param'
        // followed by no value
        return default_list
    } else if (source_value instanceof String) {
        if (source_value.trim() == '') {
            return default_list
        } else {
            return source_value.tokenize(',').collect { it.trim() }
        }
    } else {
        // this is the case in which a parameter was set to a numeric value,
        // e.g., "--param 1000" or "--param 20.3"
        return [source_value]
    }
}

def stitching_container_param(Map ps) {
    def stitching_container = ps.stitching_container
    if (!stitching_container)
        "${ps.mfrepo}/stitching:1.1.0"
    else
        stitching_container
}

def airlocalize_container_param(Map ps) {
    def spot_extraction_container = ps.spot_extraction_container
    if (!spot_extraction_container)
        "${ps.mfrepo}/spot_extraction:1.2.0"
    else
        airlocalize_container
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
        "${ps.mfrepo}/registration:1.2.3"
    else
        registration_container
}

def spots_assignment_container_param(Map ps) {
    def spots_assignment_container = ps.spots_assignment_container
    if (!spots_assignment_container)
        "${ps.mfrepo}/spot_assignment:1.3.0"
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
    if (stitching_ref=="all") {
        return ''
    }
    def ch_num_lookup = (stitching_ref =~ /(\d+)/)
    if (ch_num_lookup.find()) {
        return ch_num_lookup[0][1]
    } else {
        return ''
    }
}

def airlocalize_xy_stride_param(Map ps) {
    def airlocalize_xy_stride = ps.airlocalize_xy_stride
    if (!airlocalize_xy_stride) {
        return 1024
    } else {
        return airlocalize_xy_stride
    }
}

def airlocalize_xy_overlap_param(Map ps) {
    def airlocalize_xy_overlap = ps.airlocalize_xy_overlap
    if (!airlocalize_xy_overlap) {
        airlocalize_xy_overlap = (int) (0.05 * airlocalize_xy_stride_param(ps))
        return airlocalize_xy_overlap < 50 ?  50 : airlocalize_xy_overlap
    } else {
        return airlocalize_xy_overlap
    }
}

def airlocalize_z_stride_param(Map ps) {
    def airlocalize_z_stride = ps.airlocalize_z_stride
    if (!airlocalize_z_stride) {
        return 512
    } else {
        return airlocalize_z_stride
    }
}

def airlocalize_z_overlap_param(Map ps) {
    def airlocalize_z_overlap = ps.airlocalize_z_overlap
    if (!airlocalize_z_overlap) {
        airlocalize_z_overlap = (int) (0.05 * airlocalize_z_stride_param(ps))
        return airlocalize_z_overlap < 50 ?  50 : airlocalize_z_overlap
    } else {
        return airlocalize_z_overlap
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
