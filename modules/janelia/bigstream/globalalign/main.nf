process BIGSTREAM_GLOBALALIGN {
    container { task.ext.container ?: 'janeliascicomp/bigstream:1.2.9-dask2023.10.1-py11' }
    cpus { bigstream_cpus }
    memory "${bigstream_mem_in_gb} GB"

    input:
    tuple val(meta),
          path(fix_image, stageAs: 'fix/*'),
          val(fix_image_subpath),
          path(mov_image, stageAs: 'mov/*'),
          val(mov_image_subpath),
          path(fix_mask, stageAs: 'fixmask/*'),
          val(fix_mask_subpath),
          path(mov_mask, stageAs: 'movmask/*'),
          val(mov_mask_subpath),
          val(steps),
          path(output_dir),
          val(transform_name), // name of the affine transformation
          val(alignment_name) // alignment name
    val(bigstream_cpus)
    val(bigstream_mem_in_gb)

    output:
    tuple val(meta),
          env(fix_fullpath), val(fix_image_subpath),
          env(mov_fullpath), val(mov_image_subpath),
          env(output_fullpath),
          val(transform_name_output),
          val(alignment_name)                      , emit: results

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fix_image_subpath_arg = fix_image_subpath ? "--fixed-global-subpath ${fix_image_subpath}" : ''
    def mov_image_subpath_arg = mov_image_subpath ? "--moving-global-subpath ${mov_image_subpath}" : ''
    def fix_mask_arg = fix_mask ? "--fixed-global-mask ${fix_mask}" : ''
    def fix_mask_subpath_arg = fix_mask && fix_mask_subpath ? "--fixed-global-mask-subpath ${fix_mask_subpath}" : ''
    def mov_mask_arg = mov_mask ? "--moving-global-mask ${mov_mask}" : ''
    def mov_mask_subpath_arg = mov_mask && mov_mask_subpath ? "--moving-global-mask-subpath ${mov_mask_subpath}" : ''
    def steps_arg = steps ? "--global-registration-steps ${steps}" : ''
    def transform_name_param = transform_name
    def transform_name_arg = transform_name_param ? "--global-transform-name ${transform_name_param}" : ''
    def aligned_name_arg = alignment_name ? "--global-aligned-name ${alignment_name}" : ''

    transform_name_output = transform_name_param ?: 'affine-transform.mat'

    """
    output_fullpath=\$(readlink ${output_dir})
    mkdir -p \${output_fullpath}
    fix_fullpath=\$(readlink ${fix_image})
    mov_fullpath=\$(readlink ${mov_image})
    python /app/bigstream/scripts/main_align_pipeline.py \
        --fixed-global \${fix_fullpath} ${fix_image_subpath_arg} \
        --moving-global \${mov_fullpath} ${mov_image_subpath_arg} \
        ${fix_mask_arg} ${fix_mask_subpath_arg} \
        ${mov_mask_arg} ${mov_mask_subpath_arg} \
        ${steps_arg} \
        --global-output-dir ${output_dir} \
        ${transform_name_arg} \
        ${aligned_name_arg} \
        ${args}
    """
}
