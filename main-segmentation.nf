#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

params.input_dir = '../multifish-testdata/LHA3_R3_small/stitching/export.n5'
params.acqs = 'LHA3_R3_small'
params.output_dir = '../multifish-testdata/LHA3_R3_small/segmentation'
params.dapi_channel = 'c1'
params.segmentation_scale = 's4'
params.segmentation_model_dir = '../multifish-testdata/starfinity_model'
params.segmentation_container = 'public.ecr.aws/janeliascicomp/multifish/segmentation:1.1.0'
params.segmentation_cpus = 2
params.segmentation_memory = '20 G'
params.segmentation_tile_size = 32

include {
    get_list_or_default;
} from './param_utils'

include {
    segmentation;
} from './workflows/segmentation'

workflow {

    def input_dirs = get_list_or_default(params, 'input_dir', [])
    def acqs = get_list_or_default(params, 'acqs', [])
    def output_dirs = get_list_or_default(params, 'output_dir', [])

    def segmentation_res = segmentation(
        Channel.fromList(input_dirs).map { file(it) } ,
        Channel.fromList(acqs),
        Channel.fromList(output_dirs).map { file(it) },
        params.dapi_channel,
        params.segmentation_scale,
        params.segmentation_model_dir,
    )

    segmentation_res | view

}
