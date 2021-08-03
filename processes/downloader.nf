process download {
    label 'small'
    stageInMode 'copy'

    container { params.downloader_container }

    input:
    tuple file(manifest_file), val(output_dir)

    output:
    val(output_dir)

    script:
    """
    download_dataset.sh "${manifest_file}" "${output_dir}" "${params.verify_md5}"
    """
}

