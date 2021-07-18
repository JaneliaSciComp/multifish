process download {
    label 'small'

    container { params.downloader_container }

    input:
    tuple val(data_set_path), val(output_dir)

    output:
    val(output_dir)

    script:
    """
    download_dataset.sh "${data_set_path}" "${output_dir}" "${params.verify_md5}"
    """
}

