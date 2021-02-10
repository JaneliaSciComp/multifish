def default_mf_params() {
    def multifish_container_repo = 'registry.int.janelia.org/janeliascicomp'
    def default_airlocalize_params = '/app/airlocalize/params/air_localize_default_params.txt'

    [
        mfrepo: multifish_container_repo,
        spotextraction_container: '',
        segmentation_container: '',
        registration_container: '',

        acq_names: '', // this is the default parameter for all acquisitions that must be processed
                       // should only be used when all steps must be performed for all acquisions
        output_dir: '',

        // stitching params
        stitching_app: 'external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar',
        stitching_output: 'stitching',
        resolution: '0.23,0.23,0.42',
        axis: '-x,y,z',
        channels: 'c0,c1,c2,c3',
        block_size: '128,128,64',
        registration_channel_for_stitching: '2',
        stitching_mode: 'incremental',
        stitching_padding: '0,0,0',
        blur_sigma: '2',

        dapi_channel: 'c2', // DAPI channel used to drive both the segmentation and the registration
        reference_acq_name: '', // this is the default parameter for the fixed round and 
                                // should be used only when all steps that require a fixed round must be done

        // spot extraction params
        spot_extraction_output: 'spots',
        scale_4_spot_extraction: 's0',
        spot_extraction_xy_stride: 0, // use the default defined by spot_extraction_xy_stride_param
        spot_extraction_xy_overlap: 0, // use the default defined by spot_extraction_xy_overlap_param
        spot_extraction_z_stride: 0, // use the default defined by spot_extraction_z_stride_param
        spot_extraction_z_overlap: 0, // use the default defined by spot_extraction_z_overlap_param
        spot_extraction_dapi_correction_channels: 'c3',
        default_airlocalize_params: default_airlocalize_params,
        per_channel_air_localize_params: ",,,",
        spot_extraction_cpus: 1,

        // segmentatioon params
        segmentation_model_dir: '',
        segmentation_output: 'segmentation',
        scale_4_segmentation: 's2',
        predict_cpus: 3, // it needs at least 3 cpus for Janelia cluster config because of memory requirements

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
        aff_scale_transform_cpus: 1, // cores for affine scale transforms
        def_scale_transform_cpus: 8, // cores for deformable scale transforms
        stitch_registered_cpus: 2,
        final_transform_cpus: 12,

        // warp spots parameters
        warp_spots_cpus: 2,
    ]
}

def get_value_or_default(Map ps, String param, String default_value) {
    if (ps[param])
        ps[param]
    else
        default_value
}

def output_dir_param(Map ps) {
    def output_dir = ps.output_dir
    if (!output_dir)
        ps.data_dir
    else
        output_dir
}

def segmentation_container_param(Map ps) {
    def segmentation_container = ps.segmentation_container
    if (!segmentation_container)
        "${ps.mfrepo}/segmentation:1.0"
    else
        segmentation_container
}

def spotextraction_container_param(Map ps) {
    def spotextraction_container = ps.spotextraction_container
    if (!spotextraction_container)
        "${ps.mfrepo}/spotextraction:1.0"
    else
        spotextraction_container
}

def registration_container_param(Map ps) {
    def registration_container = ps.registration_container
    if (!registration_container)
        "${ps.mfrepo}/registration:1.0"
    else
        registration_container
}

def get_acqs_for_step(Map ps, String step_param, List default_val) {
    def step_acq_names
    if (ps[step_param])
        step_acq_names = ps[step_param]
    else
        step_acq_names = null
    return step_acq_names ? step_acq_names.tokenize(',') : default_val
}

def spot_extraction_xy_stride_param(Map ps) {
    def spot_extraction_xy_stride = ps.spot_extraction_xy_stride
    if (!spot_extraction_xy_stride) {
        return 2048
    } else {
        return spot_extraction_xy_stride
    }
}

def spot_extraction_xy_overlap_param(Map ps) {
    def spot_extraction_xy_overlap = ps.spot_extraction_xy_overlap
    if (!spot_extraction_xy_overlap) {
        // consider 20% of xy stride
        spot_extraction_xy_overlap = (int) (0.05 * spot_extraction_xy_stride_param(ps))
        return spot_extraction_xy_overlap < 50 ?  50 : spot_extraction_xy_overlap
    } else {
        return spot_extraction_xy_overlap
    }
}

def spot_extraction_z_stride_param(Map ps) {
    def spot_extraction_z_stride = ps.spot_extraction_z_stride
    if (!spot_extraction_z_stride) {
        return 1024
    } else {
        return spot_extraction_z_stride
    }
}

def spot_extraction_z_overlap_param(Map ps) {
    def spot_extraction_z_overlap = ps.spot_extraction_z_overlap
    if (!spot_extraction_z_overlap) {
        // consider 20% of z stride
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
