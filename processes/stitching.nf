process prepare_stitching_data {
    input:
    val(input_dir)
    val(output_dir)
    val(acq_name)
    val(stitching_output)

    output:
    tuple val(acq_name), val(stitching_dir)

    script:
    acq_output_dir = "${output_dir}/${acq_name}"
    stitching_dir = stitching_output == ''
        ? acq_output_dir
        : "${acq_output_dir}/${stitching_output}"
    mvl = "${input_dir}/${acq_name}.mvl"
    mvl_link = "${stitching_dir}/${acq_name}.mvl"
    czi = "${input_dir}/${acq_name}.czi"
    czi_link = "${stitching_dir}/${acq_name}.czi"
    """
    mkdir -p "${stitching_dir}"
    ln -s "${mvl}" "${mvl_link}" || true
    ln -s "${czi}" "${czi_link}" || true
    """
}
