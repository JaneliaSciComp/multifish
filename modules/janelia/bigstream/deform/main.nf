process BIGSTREAM_DEFORM {
    tag "${meta.id}"
    container { task.ext.container ?: 'ghcr.io/janeliascicomp/bigstream:1.3.2-dask2024.4.1-py11' }
    cpus { bigstream_cpus }
    memory "${bigstream_mem_in_gb} GB"

    input:
    tuple val(meta),
          path(fix_image, stageAs: 'fix/*'),val(fix_image_subpath),val(fix_spacing),
          path(mov_image, stageAs: 'mov/*'),val(mov_image_subpath),val(mov_spacing),
          path(affine_transforms, stageAs: 'affine/*'), // one or more affine transformations (paths to the corresponding affine.mat)
          path(deform_dir, stageAs: 'deformation/*'), // location of the displacement vector
          val(deform_subpath), // displacement vector subpath
          path(output_dir, stageAs: 'warped/*'),
          val(output_subpath)
    tuple val(dask_scheduler),
          path(dask_config) // this is optional - if undefined pass in as empty list ([])
    val(bigstream_cpus)
    val(bigstream_mem_in_gb)

    output:
    tuple val(meta),
          env(fix_fullpath), val(fix_image_subpath),
          env(mov_fullpath), val(mov_image_subpath),
          env(output_fullpath), val(output_subpath)  , emit: results

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fix_image_subpath_arg = fix_image_subpath ? "--fix-subpath ${fix_image_subpath}" : ''
    def fix_spacing_arg = fix_spacing ? "--fix-spacing ${fix_spacing}" : ''
    def mov_image_subpath_arg = mov_image_subpath ? "--mov-subpath ${mov_image_subpath}" : ''
    def mov_spacing_arg = mov_spacing ? "--mov-spacing ${mov_spacing}" : ''
    def affine_transforms_arg
    if (affine_transforms) {
      if (affine_transforms instanceof Collection) {
            affine_transforms_arg = "--affine-transformations $affine_transforms.join(',')"
      } else {
            affine_transforms_arg = "--affine-transformations ${affine_transforms}"
      }
    } else {
      affine_transforms_arg = ''
    }
    def local_transform_arg = deform_dir ? "--local-transform ${deform_dir}" : ''
    def local_transform_subpath_arg = deform_dir && deform_subpath ? "--local-transform-subpath ${deform_subpath}" : ''
    def output_subpath_arg = output_subpath ? "--output-subpath ${output_subpath}" : ''
    def dask_scheduler_arg = dask_scheduler ? "--dask-scheduler ${dask_scheduler}" : ''
    def dask_config_arg = dask_scheduler && dask_config ? "--dask-config ${dask_config}" : ''

    """
    fix_fullpath=\$(readlink ${fix_image})
    mov_fullpath=\$(readlink ${mov_image})
    output_fullpath=\$(readlink ${output_dir})
    mkdir -p \${output_fullpath}
    python /app/bigstream/scripts/main_apply_local_transform.py \
        --fix \${fix_fullpath} ${fix_image_subpath_arg} ${fix_spacing_arg} \
        --moving \${mov_fullpath} ${mov_image_subpath_arg} ${mov_spacing_arg} \
        ${affine_transforms_arg} \
        ${local_transform_arg} ${local_transform_subpath_arg} \
        --output \${output_fullpath} ${output_subpath_arg} \
        ${dask_scheduler_arg} \
        ${dask_config_arg} \
        ${args}
    """
}
