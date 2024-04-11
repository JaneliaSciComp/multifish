process BIGSTREAM_LOCALALIGN {
    container { task.ext.container ?: 'janeliascicomp/bigstream:1.2.9-dask2023.10.1-py11' }
    cpus { bigstream_cpus }
    memory "${bigstream_mem_in_gb} GB"

    input:
    tuple val(meta),
          path(fix_image, stageAs: 'fix/*'), val(fix_image_subpath),
          path(mov_image, stageAs: 'mov/*'), val(mov_image_subpath),
          path(fix_mask, stageAs: 'fixmask/*'), val(fix_mask_subpath),
          path(mov_mask, stageAs: 'movmask/*'), val(mov_mask_subpath),
          path(affine_dir, stageAs: 'global_affine/*'), // this is the global affine location
          val(affine_transform_name), // global affine file name
          val(steps),
          path(output_dir),
          val(transform_name),
          val(transform_subpath),
          val(inv_transform_name),
          val(inv_transform_subpath),
          val(alignment_name) // alignment name

    tuple val(dask_scheduler),
          path(dask_config) // this is optional - if undefined pass in as empty list ([])

    val(bigstream_cpus)

    val(bigstream_mem_in_gb)

    output:
    tuple val(meta),
          env(fix_fullpath), val(fix_image_subpath),
          env(mov_fullpath), val(mov_image_subpath),
          env(affine_fullpath),
          val(affine_transform_name),
          env(output_fullpath),
          val(transform_name), val(transform_subpath_output),
          val(inv_transform_name), val(inv_transform_subpath_output),
          val(alignment_name)                                       , emit: results

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fix_image_subpath_arg = fix_image_subpath ? "--fixed-local-subpath ${fix_image_subpath}" : ''
    def mov_image_subpath_arg = mov_image_subpath ? "--moving-local-subpath ${mov_image_subpath}" : ''
    def fix_mask_arg = fix_mask ? "--fixed-local-mask \$(readlink ${fix_mask})" : ''
    def fix_mask_subpath_arg = fix_mask && fix_mask_subpath ? "--fixed-local-mask-subpath ${fix_mask_subpath}" : ''
    def mov_mask_arg = mov_mask ? "--moving-local-mask \$(readlink ${mov_mask})" : ''
    def mov_mask_subpath_arg = mov_mask && mov_mask_subpath ? "--moving-local-mask-subpath ${mov_mask_subpath}" : ''
    def affine_dir_arg = affine_dir ? "--global-output-dir ${affine_dir}" : ''
    def affine_transform_name_arg = affine_transform_name ? "--global-transform-name ${affine_transform_name}" : ''
    def steps_arg = steps ? "--local-registration-steps ${steps}" : ''
    def transform_name_arg = transform_name ? "--local-transform-name ${transform_name}" : ''
    def transform_subpath_param = transform_subpath
    def transform_subpath_arg = transform_subpath_param ? "--local-transform-subpath ${transform_subpath_param}" : ''
    def inv_transform_name_arg = inv_transform_name ? "--local-inv-transform-name ${inv_transform_name}" : ''
    def inv_transform_subpath_param = inv_transform_subpath
    def inv_transform_subpath_arg = inv_transform_subpath_param ? "--local-inv-transform-subpath ${inv_transform_subpath_param}" : ''
    def aligned_name_arg = alignment_name ? "--local-aligned-name ${alignment_name}" : ''
    def dask_scheduler_arg = dask_scheduler ? "--dask-scheduler ${dask_scheduler}" : ''
    def dask_config_arg = dask_scheduler && dask_config ? "--dask-config ${dask_config}" : ''

    transform_subpath_output = transform_subpath_param ?: mov_image_subpath
    inv_transform_subpath_output = inv_transform_subpath_param ?: transform_subpath_output

    """
    output_fullpath=\$(readlink ${output_dir})
    echo "Create output directory: \${output_fullpath}"
    mkdir -p \${output_fullpath}
    fix_fullpath=\$(readlink ${fix_image})
    mov_fullpath=\$(readlink ${mov_image})
    if [[ "${affine_dir}" != "" ]] ; then
        affine_fullpath=\$(readlink ${affine_dir})
    else
        affine_fullpath=
    fi
    python /app/bigstream/scripts/main_align_pipeline.py \
        --fixed-local \${fix_fullpath} ${fix_image_subpath_arg} \
        --moving-local \${mov_fullpath} ${mov_image_subpath_arg} \
        ${fix_mask_arg} ${fix_mask_subpath_arg} \
        ${mov_mask_arg} ${mov_mask_subpath_arg} \
        ${affine_dir_arg} \
        ${affine_transform_name_arg} \
        ${steps_arg} \
        --local-output-dir ${output_dir} \
        ${transform_name_arg} ${transform_subpath_arg} \
        ${inv_transform_name_arg} ${inv_transform_subpath_arg} \
        ${aligned_name_arg} \
        ${dask_scheduler_arg} \
        ${dask_config_arg} \
        ${args}
    """

}
