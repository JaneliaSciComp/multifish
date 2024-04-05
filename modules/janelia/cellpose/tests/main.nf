include { CELLPOSE   } from '../../../../modules/janelia/cellpose/main'

process UNTAR_RAW_INPUT {
    container { task.ext.container }

    input: path(tarfile, stageAs:'input-data/*')
    output: path('input-data/*.n5')

    script:
    """
    tar -xvf $tarfile -C input-data
    """
}

workflow test_cellpose_standalone {
    test_cellpose(
        Channel.of(
            file(params.test_data['stitched_images']['n5']['r1_n5'])
        )
    )
}

workflow test_cellpose {
    take:
    input_test_data

    main:
    def cellpose_test_data = UNTAR_RAW_INPUT (input_test_data) |
    map { input_image ->
        def cellpose_models_path = params.cellpose_models_dir
            ? file(params.cellpose_models_dir) : []
        def cellpose_working_path = params.cellpose_work_dir
            ? file(params.cellpose_work_dir) : []

        [
            [
                id: 'test_cellpose',
            ],
            input_image, params.input_image_subpath,
            cellpose_models_path,
            file(params.output_image_dir),
            params.output_image_name,
            cellpose_working_path,
        ]
    }
    cellpose_test_data.subscribe { log.info "Cellpose path inputs: $it" }

    def cellpose_results = CELLPOSE(
        cellpose_test_data,
        Channel.of(['', []]),
        params.cellpose_driver_cpus,
        params.cellpose_driver_mem_gb,
    )

    cellpose_results.results.subscribe {
        log.info "Cellpose results: $it"
    }

}
