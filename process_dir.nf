#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process test {
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

