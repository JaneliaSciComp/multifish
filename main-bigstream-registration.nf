#!/usr/bin/env nextflow
/*
    Image registration using Bigstream
*/
// path to the fixed n5 image
params.fixed = ""


// path to the moving n5 image
params.moving = ""

// path to the folder where you'd like all outputs to be written
params.outdir = ""

global_fix = file(params.global_fix)
global_mov = file(params.global_mov)
local_fix = file(params.local_fix)
local_mov = file(params.local_mov)

global_output_dir = file(params.global_output_dir)
local_output_dir = file(params.local_output_dir)


log.info """\
    BIGSTREAM REGISTRATION PIPELINE
    ===================================
    global fixed    : "${global_fix}${params.global_fix_subpath ? ':' + params.global_fix_subpath : ''}"
    global moving   : "${global_mov}${params.global_mov_subpath ? ':' + params.global_mov_subpath : ''}"
    global steps    : "${params.global_steps}"
    local fixed     : "${local_fix}${params.local_fix_subpath ? ':' + params.local_fix_subpath : ''}"
    local moving    : "${local_mov}${params.local_mov_subpath ? ':' + params.local_mov_subpath : ''}"
    local steps     : "${params.local_steps}"
    global outdir   : "${global_output_dir}"
    local outdir    : "${local_output_dir}"
    """
    .stripIndent()


workflow {
    def fix_name = params.fix_name ?: global_fix.name
    def mov_name = params.mov_name ?: moving.name

    def meta = [
        id: "${moving_name}-to-${fixed_name}"
    ]


    def additional_deformations = create_addional_deformations_from_subpaths(
        local_mov,
        params.additional_deformed_subpaths,
        local_output_dir,
    ) +
    create_addional_deformations_from_paths(
        params.additional_deformed_paths,
        local_output_dir,
    )

    def registration_input = Channel.of(
        [
            meta,

            global_fix, params.global_fix_subpath,
            global_mov, params.global_mov_subpath,
            params.global_fix_mask ? file(params.global_fix_mask) : '', params.global_fix_mask_subpath,
            params.global_mov_mask ? file(params.global_mov_mask) : '', params.global_mov_mask_subpath,
            params.global_steps,
            global_output_dir,
            params.global_transform_name,
            params.global_align_name,

            local_fix, params.local_fix_subpath,
            local_mov, params.local_mov_subpath,
            params.local_fix_mask ? file(params.local_fix_mask) : '', params.local_fix_mask_subpath,
            params.local_mov_mask ? file(params.local_mov_mask) : '', params.local_mov_mask_subpath,
            params.local_steps,
            local_output_dir,

            params.local_transform_name, params.local_transform_subpath,
            params.local_inv_transform_name, params.local_inv_transform_subpath,
            params.local_align_name,
            additional_deformations,
            params.with_dask,
            params.dask_work_dir ? file(params.dask_work_dir) : '',
            params.dask_config ? file(params.dask_config) : '',
            params.local_align_workers,
            params.local_align_min_workers,
            params.local_align_worker_cpus,
            params.local_align_worker_mem_gb,
        ]
    )

    BIGSTREAM_REGISTRATION(
        registration_input,
        params.global_align_cpus,
        params.global_align_mem_gb,
        params.local_align_cpus,
        params.local_align_mem_gb,
    )
}

workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

def create_addional_deformations_from_subpaths(image, image_subpaths, output_dir) {
    if (image_subpaths) {
        image_subpaths.tokenize(' ')
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
        image_paths.tokenize(' ')
            .collect { it.trim() }
            .collect { image_path ->
                def image_file = file(image_path)
                [
                    image_file,
                    image_file.name,
                    output_dir,
                ]
            }

    } else {
        []
    }
}