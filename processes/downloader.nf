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

process publish {
    label 'small'

    container { params.downloader_container }

    input:
    tuple val(output_dir), val(publish_dir)

    output:
    val(output_dir)

    script:
    """
    mkdir -p "${publish_dir}"
    rsync -a --exclude stitching "${output_dir}/" "${publish_dir}/"
    """
}
