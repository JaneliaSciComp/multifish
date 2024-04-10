process BIGSTREAM_TRANSFORMCOORDS {
    container { task.ext.container ?: 'janeliascicomp/bigstream:1.2.9-dask2023.10.1-py11' }
    cpus { bigstream_cpus }
    memory "${bigstream_mem_in_gb} GB"

    input:
    tuple val(meta),
          path(input_coords),
          path(output_dir),
          val(warped_coords_name)
    tuple path(source_image), val(source_image_subpath)
    tuple val(resolution), val(downsampling_factors)
    path(affine_transforms) // optional affine transforms
    tuple path(deform_dir), // optional vector displacement field
          val(deform_subpath)
    tuple val(dask_scheduler),
          path(dask_config) // this is optional - if undefined pass in as empty list ([])
    val(bigstream_cpus)
    val(bigstream_mem_in_gb)

    output:
    tuple val(meta), path(input_coords), env(warped_coords),          emit: results
    tuple val(meta), env(source_fullpath), val(source_image_subpath), emit: source

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def pixel_resolution_arg = resolution ? "--pixel-resolution ${resolution}" : ''
    def downsampling_arg = downsampling_factors ? "--downsampling ${downsampling_factors}" : ''
    def source_image_arg = source_image ? "--input-volume ${source_image}" : ''
    def source_image_subpath_arg = source_image_subpath ? "--input-dataset ${source_image_subpath}" : ''
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
    def deform_arg = deform_dir ? "--vector-field-transform ${deform_dir}" : ''
    def deform_subpath_arg = deform_subpath ? "--vector-field-transform-subpath ${deform_subpath}" : ''
    def dask_scheduler_arg = dask_scheduler ? "--dask-scheduler ${dask_scheduler}" : ''
    def dask_config_arg = dask_scheduler && dask_config ? "--dask-config ${dask_config}" : ''

    """
    if [[ "${source_image}" != "" ]] ; then
        source_fullpath=\$(readlink ${source_image})
    else
        source_fullpath=
    fi
    output_fullpath=\$(readlink ${output_dir})
    mkdir -p \${output_fullpath}
    warped_coords="\${output_fullpath}/${warped_coords_name}"
    python /app/bigstream/scripts/main_apply_transform_coords.py \
        --input-coords ${input_coords} \
        --output-coords \${warped_coords} \
        ${pixel_resolution_arg} \
        ${downsampling_arg} \
        ${source_image_arg} ${source_image_subpath_arg} \
        ${affine_transforms_arg} \
        ${deform_arg} ${deform_subpath_arg} \
        ${dask_scheduler_arg} \
        ${dask_config_arg} \
        ${args}
    """

}
