process BIGSTREAM_GLOBALALIGN {
    container { task.ext.container ?: 'ghcr.io/janeliascicomp/bigstream:1.3.1-dask2024.4.1-py11' }
    cpus { bigstream_cpus }
    memory "${bigstream_mem_in_gb} GB"

    input:
    tuple val(meta),
          path(fix_image, stageAs: 'fix/*'), val(fix_image_subpath),
          path(mov_image, stageAs: 'mov/*'), val(mov_image_subpath),
          path(fix_mask, stageAs: 'fixmask/*'), val(fix_mask_subpath),
          path(mov_mask, stageAs: 'movmask/*'), val(mov_mask_subpath),
          val(steps),
          path(transform_dir, stageAs: 'transform/*'), val(transform_name),
          path(align_dir, stageAs: 'align/*'), val(align_name), val(align_subpath)

    path(bigstream_config)

    val(bigstream_cpus)

    val(bigstream_mem_in_gb)

    output:
    tuple val(meta),
          env(full_fix_image), val(fix_image_subpath),
          env(full_mov_image), val(mov_image_subpath),
          env(full_transform_dir), val(transform_name),
          env(full_align_dir), val(align_name), val(align_subpath) , emit: results

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fix_image_arg = fix_image ? "--global-fix \${full_fix_image}" : ''
    def fix_image_subpath_arg = fix_image_subpath ? "--global-fix-subpath ${fix_image_subpath}" : ''
    def mov_image_arg = mov_image ? "--global-mov \${full_mov_image}" : ''
    def mov_image_subpath_arg = mov_image_subpath ? "--global-mov-subpath ${mov_image_subpath}" : ''
    def fix_mask_arg = fix_mask ? "--global-fix-mask ${fix_mask}" : ''
    def fix_mask_subpath_arg = fix_mask && fix_mask_subpath ? "--global-fix-mask-subpath ${fix_mask_subpath}" : ''
    def mov_mask_arg = mov_mask ? "--global-mov-mask ${mov_mask}" : ''
    def mov_mask_subpath_arg = mov_mask && mov_mask_subpath ? "--global-mov-mask-subpath ${mov_mask_subpath}" : ''
    def steps_arg = steps ? "--global-registration-steps ${steps}" : ''
    def transform_dir_arg = transform_dir ? "--global-transform-dir \${full_transform_dir}" : ''
    def transform_name_arg = transform_name ? "--global-transform-name ${transform_name}" : ''
    def align_dir_arg = align_dir ? "--global-align-dir \${full_align_dir}" : ''
    def align_name_arg = align_name ? "--global-align-name ${align_name}" : ''
    def align_subpath_arg = align_subpath ? "--global-align-subpath ${align_subpath}" : ''
    def bigstream_config_arg = bigstream_config ? "--align-config ${bigstream_config}" : ''

    """
    if [[ "${fix_image}" != "" ]];  then
        full_fix_image=\$(readlink -m ${fix_image})
        echo "Fix volume full path: \${full_fix_image}"
    else
        full_fix_image=
        echo "No fix volume provided"
    fi
    if [[ "${mov_image}" != "" ]];  then
        full_mov_image=\$(readlink -m ${mov_image})
        echo "Moving volume full path: \${full_mov_image}"
    else
        full_mov_image=
        echo "No moving volume provided"
    fi

    if [[ "${transform_dir}" != "" ]] ; then
        full_transform_dir=\$(readlink -m ${transform_dir})
        if [[ ! -e \${full_transform_dir} ]] ; then
            echo "Create transform directory: \${full_transform_dir}"
            mkdir -p \${full_transform_dir}
        else
            echo "Transform directory: \${full_transform_dir} - already exists"
        fi
        if [[ "${transform_name}" != "" ]] ; then
            # this is to cover the case when the transform name contains a relative path
            # e.g. aff/affine.mat
            data_dir=\$(dirname "\${full_transform_dir}/${transform_name}")
            if [[ "\${data_dir}" !=  "\${full_transform_dir}" ]] ; then
                echo "Create directory for affine transformation: \${data_dir}"
                mkdir -p \${data_dir}
            fi
        fi
    else
        full_transform_dir=
    fi

    if [[ "${align_dir}" != "" ]] ; then
        full_align_dir=\$(readlink -m ${align_dir})
        if [[ ! -e \${full_align_dir} ]] ; then
            echo "Create align directory: \${full_align_dir}"
            mkdir -p \${full_align_dir}
        else
            echo "Align directory: \${full_align_dir} - already exists"
        fi
        if [[ "${align_name}" != "" ]] ; then
            # this is to cover the case when the transform name contains a relative path
            # e.g. aff/affine.n5
            data_dir=\$(dirname "\${full_align_dir}/${align_name}")
            if [[ "\${data_dir}" !=  "\${full_align_dir}" ]] ; then
                echo "Create directory for affine transformed result: \${data_dir}"
                mkdir -p \${data_dir}
            fi
        fi
    else
        full_align_dir=
    fi

    python /app/bigstream/scripts/main_global_align_pipeline.py \
        ${fix_image_arg} ${fix_image_subpath_arg} \
        ${mov_image_arg} ${mov_image_subpath_arg} \
        ${fix_mask_arg} ${fix_mask_subpath_arg} \
        ${mov_mask_arg} ${mov_mask_subpath_arg} \
        ${steps_arg} \
        ${bigstream_config_arg} \
        ${transform_dir_arg} ${transform_name_arg} \
        ${align_dir_arg} ${align_name_arg} ${align_subpath_arg} \
        ${args}
    """
}
