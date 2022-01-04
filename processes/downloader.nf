include { create_container_options } from './utils'

process download {
    label 'small'
    stageInMode 'copy'

    container { params.downloader_container }
    containerOptions { create_container_options([ file(output_dir).parent ]) }

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
    containerOptions { create_container_options([ file(publish_dir).parent ]) }

    input:
    tuple val(output_dir), val(publish_dir)

    output:
    val(output_dir)

    script:
    """
    mkdir -p "${publish_dir}"
    rsync -a --exclude stitching "${output_dir}/" "${publish_dir}/"
    # TODO: use include file, e.g.
    # rsync -arm --include-from=$HOME/dev/multifish/include.txt --exclude="*"
    """
}
