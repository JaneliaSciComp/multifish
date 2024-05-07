#!/usr/bin/env nextflow
/*
    Image registration using Bigstream
*/

include { BIGSTREAM_REGISTRATION } from './subworkflows/janelia/bigstream_registration/main.nf'

global_fix = params.bigstream_global_fix ? file(params.bigstream_global_fix) : ''
global_mov = params.bigstream_global_mov ? file(params.bigstream_global_mov) : ''
local_fix = params.bigstream_local_fix ? file(params.bigstream_local_fix) : ''
local_mov = params.bigstream_local_mov ? file(params.bigstream_local_mov) : ''
bigstream_config = params.bigstream_config ? file(params.bigstream_config): ''
with_dask = params.with_dask
dask_config = params.dask_config ? file(params.dask_config): ''
dask_work_dir = params.dask_work_dir ? file(params.dask_work_dir): ''

global_output_dir = params.bigstream_global_output_dir ? file(params.bigstream_global_output_dir) : ''
local_output_dir = params.bigstream_local_output_dir ? file(params.bigstream_local_output_dir) : ''

log.info """\
    BIGSTREAM REGISTRATION PIPELINE
    ===================================
    global fixed     : "${global_fix}${params.bigstream_global_fix_subpath ? ':' + params.bigstream_global_fix_subpath : ''}"
    global moving    : "${global_mov}${params.bigstream_global_mov_subpath ? ':' + params.bigstream_global_mov_subpath : ''}"
    global steps     : "${params.bigstream_global_steps}"
    local fixed      : "${local_fix}${params.bigstream_local_fix_subpath ? ':' + params.bigstream_local_fix_subpath : ''}"
    local moving     : "${local_mov}${params.bigstream_local_mov_subpath ? ':' + params.bigstream_local_mov_subpath : ''}"
    local steps      : "${params.bigstream_local_steps}"
    global outdir    : "${global_output_dir}"
    local outdir     : "${local_output_dir}"
    bigstream config : "${bigstream_config}"
    with dask        : "${with_dask}"
    dask config      : "${dask_config}"
    """
    .stripIndent()


workflow {
    def fix_name = get_name(params.bigstream_fix_name, global_fix, local_fix, 'fix')
    def mov_name = get_name(params.bigstream_mov_name, global_mov, local_mov, 'mov')

    def meta = [
        id: "${mov_name}-to-${fix_name}"
    ]

    def additional_deformations = create_addional_deformations(
        local_fix, params.bigstream_local_fix_subpath, params.bigstream_local_fix_spacing,
        params.bigstream_additional_deformations,
        local_output_dir, params.bigstream_local_align_name,
    )

    def registration_input = Channel.of(
        [
            meta,

            global_fix, params.bigstream_global_fix_subpath,
            global_mov, params.bigstream_global_mov_subpath,
            params.bigstream_global_fix_mask ? file(params.bigstream_global_fix_mask) : '', params.bigstream_global_fix_mask_subpath,
            params.bigstream_global_mov_mask ? file(params.bigstream_global_mov_mask) : '', params.bigstream_global_mov_mask_subpath,
            params.bigstream_global_steps,
            global_output_dir,
            params.bigstream_global_transform_name,
            params.bigstream_global_align_name,

            local_fix, params.bigstream_local_fix_subpath,
            local_mov, params.bigstream_local_mov_subpath,
            params.bigstream_local_fix_mask ? file(params.bigstream_local_fix_mask) : '', params.bigstream_local_fix_mask_subpath,
            params.bigstream_local_mov_mask ? file(params.bigstream_local_mov_mask) : '', params.bigstream_local_mov_mask_subpath,
            params.bigstream_local_steps,
            local_output_dir,

            params.bigstream_local_transform_name, params.bigstream_local_transform_subpath,
            params.bigstream_local_inv_transform_name, params.bigstream_local_inv_transform_subpath,
            params.bigstream_local_align_name,
            additional_deformations,
            with_dask,
            dask_work_dir,
            dask_config,
            params.bigstream_local_align_workers,
            params.bigstream_local_align_min_workers,
            params.bigstream_local_align_worker_cpus,
            params.bigstream_local_align_worker_mem_gb,
        ]
    )

    BIGSTREAM_REGISTRATION(
        registration_input,
        bigstream_config,
        params.bigstream_global_align_cpus,
        params.bigstream_global_align_mem_gb,
        params.bigstream_local_align_cpus,
        params.bigstream_local_align_mem_gb,
    )
}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

def create_addional_deformations(ref_path, ref_subpath, ref_scale,
                                 deformation_entries,
                                 output_path, output_name) {
    if (deformation_entries) {
        def deformation_entries_list
        if (deformation_entries instanceof Collection) {
            deformation_entries_list = deformation_entries
        } else {
            deformation_entries_list = deformation_entries.tokenize(' ')
        }
        deformation_entries_list
            .collect { it.trim() }
            .collate(3)
            .collect {
                def (image_path, image_subpath, image_scale) = it
                def image_file = file(image_path)
                def warped_image_name = output_name ?: "warped-${image_file.name}"
                def r = [
                    ref_path, image_subpath ?: ref_subpath, image_scale ?: ref_scale,
                    image_path, image_subpath, image_scale,

                    image_file,
                    '',
                    "${output_dir}/${warped_image_name}",
                ]
                log.debug "Add deformation for $r"
                r
            }
    } else {
        []
    }
}

def get_name(preferred_name, global_file, local_file, default_name) {
    if (preferred_name) {
        preferred_name
    } else if (global_file) {
        global_file.name
    } else if (local_file) {
        local_file.name
    } else {
        default_name
    }
}