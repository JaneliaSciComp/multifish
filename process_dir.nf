#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process test {
    container 'multifish/downloader:1.1.0'
    script:
    """
    echo `pwd`
    echo \$PWD
    echo \$PROCESS_DIR
    """
}

workflow {
    test()
}

