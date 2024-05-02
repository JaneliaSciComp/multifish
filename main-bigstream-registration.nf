#!/usr/bin/env nextflow
/*
    Image registration using Bigstream
*/

include { BIGSTREAM_REGISTRATION } from './subworkflows/janelia/bigstream_registration/main.nf'

global_fix = file(params.bigstream.global_fix)
global_mov = file(params.bigstream.global_mov)
local_fix = file(params.bigstream.local_fix)
local_mov = file(params.bigstream.local_mov)

global_output_dir = file(params.bigstream.global_output_dir)
local_output_dir = file(params.bigstream.local_output_dir)


log.info """\
    BIGSTREAM REGISTRATION PIPELINE
    ===================================
    global fixed    : "${global_fix}${params.bigstream.global_fix_subpath ? ':' + params.bigstream.global_fix_subpath : ''}"
    global moving   : "${global_mov}${params.bigstream.global_mov_subpath ? ':' + params.bigstream.global_mov_subpath : ''}"
    global steps    : "${params.bigstream.global_steps}"
    local fixed     : "${local_fix}${params.bigstream.local_fix_subpath ? ':' + params.bigstream.local_fix_subpath : ''}"
    local moving    : "${local_mov}${params.bigstream.local_mov_subpath ? ':' + params.bigstream.local_mov_subpath : ''}"
    local steps     : "${params.bigstream.local_steps}"
    global outdir   : "${global_output_dir}"
    local outdir    : "${local_output_dir}"
    """
    .stripIndent()


workflow {
    def fix_name = params.bigstream.fix_name ?: global_fix.name
    def mov_name = params.bigstream.mov_name ?: global_mov.name

    def meta = [
        id: "${mov_name}-to-${fix_name}"
    ]


    def additional_deformations = create_addional_deformations_from_subpaths(
        local_mov,
        params.bigstream.additional_deformed_subpaths,
        local_output_dir,
    ) +
    create_addional_deformations_from_paths(
        params.bigstream.additional_deformed_paths,
        local_output_dir,
    )

    def registration_input = Channel.of(
        [
            meta,

            global_fix, params.bigstream.global_fix_subpath,
            global_mov, params.bigstream.global_mov_subpath,
            params.bigstream.global_fix_mask ? file(params.bigstream.global_fix_mask) : '', params.bigstream.global_fix_mask_subpath,
            params.bigstream.global_mov_mask ? file(params.bigstream.global_mov_mask) : '', params.bigstream.global_mov_mask_subpath,
            params.bigstream.global_steps,
            global_output_dir,
            params.bigstream.global_transform_name,
            params.bigstream.global_align_name,

            local_fix, params.bigstream.local_fix_subpath,
            local_mov, params.bigstream.local_mov_subpath,
            params.bigstream.local_fix_mask ? file(params.bigstream.local_fix_mask) : '', params.bigstream.local_fix_mask_subpath,
            params.bigstream.local_mov_mask ? file(params.bigstream.local_mov_mask) : '', params.bigstream.local_mov_mask_subpath,
            params.bigstream.local_steps,
            local_output_dir,

            params.bigstream.local_transform_name, params.bigstream.local_transform_subpath,
            params.bigstream.local_inv_transform_name, params.bigstream.local_inv_transform_subpath,
            params.bigstream.local_align_name,
            additional_deformations,
            params.bigstream.with_dask,
            params.bigstream.dask_work_dir ? file(params.bigstream.dask_work_dir) : '',
            params.bigstream.dask_config ? file(params.bigstream.dask_config) : '',
            params.bigstream.local_align_workers,
            params.bigstream.local_align_min_workers,
            params.bigstream.local_align_worker_cpus,
            params.bigstream.local_align_worker_mem_gb,
        ]
    )

    BIGSTREAM_REGISTRATION(
        registration_input,
        params.bigstream.bigstream_config ? file(params.bigstream.bigstream_config): '',
        params.bigstream.global_align_cpus,
        params.bigstream.global_align_mem_gb,
        params.bigstream.local_align_cpus,
        params.bigstream.local_align_mem_gb,
    )
}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

def create_addional_deformations_from_subpaths(image, image_subpaths, output_dir) {
    if (image_subpaths) {
        def image_subpaths_list
        if (image_subpaths instanceof Collection) {
            image_subpaths_list = image_subpaths
        } else {
            image_subpaths_list = image_subpaths.tokenize(' ')
        }
        image_subpaths_list
            .collect { it.trim() }
            .collect { subpath ->
                [
                    image,
                    subpath,
                    output_dir,
                ]
            }
    } else {
        []
    }
}

def create_addional_deformations_from_paths(image_paths, output_dir) {
    if (image_paths) {
        def image_paths_list
        if (image_paths instanceof Collection) {
            image_paths_list = image_paths
        } else {
            image_paths_list = image_paths.tokenize(' ')
        }
        image_paths_list
            .collect { it.trim() }
            .collect { image_path ->
                def image_file = file(image_path)
                [
                    image_file,
                    '',
                    "${output_dir}/${image_file.name}",
                ]
            }
    } else {
        []
    }
}
