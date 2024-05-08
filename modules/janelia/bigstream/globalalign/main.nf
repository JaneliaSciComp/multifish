process BIGSTREAM_GLOBALALIGN {
    container { task.ext.container ?: 'janeliascicomp/bigstream:1.3.0-dask2024.4.1-py11' }
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
          val(align_name),
          val(align_subpath)

    path(bigstream_config)

    val(bigstream_cpus)

    val(bigstream_mem_in_gb)

    output:
    tuple val(meta),
          env(fix_fullpath), val(fix_image_subpath),
          env(mov_fullpath), val(mov_image_subpath),
          env(output_fullpath),
          val(transform_name),
          val(align_name), val(align_subpath)      , emit: results

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fix_image_arg = fix_image ? "--global-fix \${fix_fullpath}" : ''
    def fix_image_subpath_arg = fix_image_subpath ? "--global-fix-subpath ${fix_image_subpath}" : ''
    def mov_image_arg = mov_image ? "--global-mov \${mov_fullpath}" : ''
    def mov_image_subpath_arg = mov_image_subpath ? "--global-mov-subpath ${mov_image_subpath}" : ''
    def fix_mask_arg = fix_mask ? "--global-fix-mask ${fix_mask}" : ''
    def fix_mask_subpath_arg = fix_mask && fix_mask_subpath ? "--global-fix-mask-subpath ${fix_mask_subpath}" : ''
    def mov_mask_arg = mov_mask ? "--global-mov-mask ${mov_mask}" : ''
    def mov_mask_subpath_arg = mov_mask && mov_mask_subpath ? "--global-mov-mask-subpath ${mov_mask_subpath}" : ''
    def steps_arg = steps ? "--global-registration-steps ${steps}" : ''
    def output_dir_param = output_dir ?: ''
    def output_dir_arg = output_dir ? "--global-output-dir \${output_fullpath}" : ''
    def transform_name_param = transform_name ?: ''
    def transform_name_arg = transform_name_param ? "--global-transform-name ${transform_name_param}" : ''
    def aligned_name_arg = align_name ? "--global-align-name ${align_name}" : ''
    def aligned_subpath_arg = align_subpath ? "--global-align-subpath ${align_subpath}" : ''
    def bigstream_config_arg = bigstream_config ? "--align-config ${bigstream_config}" : ''

    """
    if [[ "${fix_image}" != "" ]];  then
        fix_fullpath=\$(readlink -m ${fix_image})
        echo "Fix volume full path: \${fix_fullpath}"
    else
        fix_fullpath=
        echo "No fix volume provided"
    fi
    if [[ "${mov_image}" != "" ]];  then
        mov_fullpath=\$(readlink -m ${mov_image})
        echo "Moving volume full path: \${mov_fullpath}"
    else
        mov_fullpath=
        echo "No moving volume provided"
    fi
    if [[ "${output_dir_param}" != "" ]] ; then
        output_fullpath=\$(readlink -m ${output_dir})
        if [[ ! -e \${output_fullpath} ]] ; then
            echo "Create output directory: \${output_fullpath}"
            mkdir -p \${output_fullpath}
        else
            echo "Output directory: \${output_fullpath} - already exists"
        fi
        if [[ "${transform_name_param}" != "" ]] ; then
            affine_dir=\$(dirname "\${output_fullpath}/${transform_name_param}")
            echo "Create directory for affine transformation: \${affine_dir}"
            mkdir -p \${affine_dir}
        fi
        if [[ "${align_name}" != "" ]] ; then
            alignment_dir=\$(dirname "\${output_fullpath}/${align_name}")
            echo "Create directory for affine alignment: \${alignment_dir}"
            mkdir -p \${alignment_dir}
        fi
    else
        output_fullpath=
    fi

    python /app/bigstream/scripts/main_align_pipeline.py \
        ${fix_image_arg} ${fix_image_subpath_arg} \
        ${mov_image_arg} ${mov_image_subpath_arg} \
        ${fix_mask_arg} ${fix_mask_subpath_arg} \
        ${mov_mask_arg} ${mov_mask_subpath_arg} \
        ${steps_arg} \
        ${bigstream_config_arg} \
        ${output_dir_arg} \
        ${transform_name_arg} \
        ${aligned_name_arg} ${aligned_subpath_arg} \
        ${args}
    """
}
