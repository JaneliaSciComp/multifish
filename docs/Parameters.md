---
layout: default
nav_order: 10
---

# Parameters

The pipeline supports many types of parameters for customization to your compute environment and data. These can all be specified on the command line using the standard syntax `--argument="value"` or `--argument "value"`. You can also use any option supported by Nextflow itself. Note that certain arguments (i.e. those interpreted by Nextflow) use a single dash instead of two.

## Environment Variables

You can export variables into your environment before calling the pipeline, or set them on the same line like this:

    SINGULARITY_TMPDIR=/opt/tmp ./examples/demo_small.sh /opt/demo_small

| Variable   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| `TMPDIR` | /tmp | Directory used for temporary files by certain processes. |
| `SINGULARITY_TMPDIR` | /tmp | Directory where Docker images are downloaded and converted to Singularity Image Format. Needs to be large enough to accommodate several GB, so moving it out of /tmp is sometimes necessary. |

## Data

Describe your input data and where pipeline results should be saved

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`data_manifest`|Name or path to the file manifest for downloading input data. Default: segmentation|If specified, the data in the manifest is downloaded into `--data_dir` before the pipeline begins. Valid values are any base filename found in the data-sets directory (e.g. "demo_small", "demo_medium") or any absolute path which points to a manifest file. By default this just downloads the segmentation model.|`string`
|`verify_md5`|Verify MD5 sum for all downloads. Default: true|This can be disabled to save time, but it's not recommended.|`string`
|`shared_work_dir`|Shared working directory accessible by all nodes. Typically something like /fsx/username/pipeline|Setting this parameter will automatically configure `data_dir`, `output_dir`, `segmentation_model_dir`, `spark_work_dir`, and `singularity_cache_dir`. You can override any of them in the hidden settings. When running on a system like AWS Batch, you should set this to an FSx for Lustre filesystem, and the final_output_dir to a Fuse-mounted S3 bucket. This will cause all processing to happen on high-performance disk, and the outputs will only be copied to slower S3 at the very last step.
|`string`
|`data_dir`|Path to the directory containing the input CZI/MVL acquisition files. If shared_work_dir is defined, this defaults to $shared_work_dir/inputs.|If `shared_work_dir` is defined, this is automatically set to `$shared_work_dir/inputs`.|`string`
|`segmentation_model_dir`|Path to the directory containing the machine learning model for segmentation.|If `shared_work_dir` is defined, this is automatically set to `$shared_work_dir/inputs/model/starfinity`. It is assumed that either the model is already there, or it will be downloaded and unzipped according to the `data_manifest`. Otherwise it defaults to ${projectDir}/external-modules/segmentation/model/starfinity, which is normally configured by setup.sh. |`string`
|`output_dir`|Path to the directory containing pipeline outputs. If shared_work_dir is defined, this defaults to $shared_work_dir/outputs.|If `shared_work_dir` is defined, this is automatically set to `$shared_work_dir/outputs`.|`string`
|`publish_dir`|Optional publishing directory where results should be copied when the pipeline is successfully completed. Typically a Fusion mount path like /fusion/s3/bucket-name.|This is useful for getting data off of FSx and onto something externally accessible like S3.|`string`
|`acq_names`|Names of acquisition rounds to process. These should match the names of the CZI/MVL files found in the data_dir.|e.g. LHA3_R3_small,LHA3_R5_small if you have files called LHA3_R3_small.czi and LHA3_R5_small.czi|`string`
|`ref_acq`|Name of the acquisition round to use as the fixed reference.|e.g. LHA3_R3_small|`string`
|`channels`|List of channel names to process.|Channel names are specified in the format "c[channel_number]", where the channel_number is 0-indexed.|`string`
|`dapi_channel`|Name of the DAPI channel.|The DAPI channel is used as a reference channel for registration, segmentation, and spot extraction.|`string`
|`bleed_channel`|Channel (other than DAPI) that needs bleedthrough correction.||`string`

## Stitching

Stitching options

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`stitching_output`|Output directory for stitching results. Default: stitching|This directory path is relative to `output_dir`|`string`
|`spark_work_dir`|Path to directory containing Spark working files and logs during stitching. Default: $shared_work_dir/spark or $workDir/spark|The Spark configuration is written here by the pipeline before launching the Spark cluster. The Spark workers write their logs back here, and it is also used to communicate the master IP address to all workers. Therefore, this must be a shared directory accessible to both the head node and all worker nodes. On AWS, Fuse-mounted S3 will not work here due to write buffering. It's best to use FSx, but EBS will also work, as long as its mounted on all the EC2 nodes. |`string`
|`spark_local_dir`|Path to directory that Spark will uses for local temporary files. Default: /tmp|This path does not need to be shared among workers, and does not need to be accessible to the head node. Usually, /tmp will do.|`string`
|`stitching_czi_pattern`|A suffix pattern that is applied to acq_names when creating CZI names e.g. "_V%02d"||`string`
|`stitching_ref`|Index of the channel used for stitching, e.g. 'c1' or '1'. You can also specify 'all' to use all of the channels. Default: the dapi_channel|If this is not defined it defaults to `dapi_channel`|`string`
|`resolution`|Voxel resolution in all 3 dimensions. Default: 0.23,0.23,0.42|This is a comma-delimited tuple as x,y,z.|`string`
|`axis`|Axis mapping for the objective->pixel coordinates conversion. Default: -x,y,z|Comma-separated axis specification with optional flips.|`string`
|`stitching_block_size`|Block size to use when converting CZI to n5 before stitching. Default: 128,128,64||`string`
|`flatfield_correction`|Apply flatfield correction before stitching? Default: true||`boolean`
|`retile_z_size`|Block size (in Z dimension) when retiling after stitching. Default: 64|This must be smaller than the number of Z slices in the data.|`integer`
|`with_fillBackground`|Use fillBackground option when running fuse step. Default: true|Turning this off may help process certain types of data that error otherwise.|`boolean`
|`stitching_mode`|Rematching mode ('full' or 'incremental'). Default: incremental||`string`
|`stitching_padding`|Padding for the overlap regions. Default: 0,0,0||`string`
|`stitching_blur_sigma`|Sigma value of the gaussian blur preapplied to the images before stitching. Default: 2||`integer`
|`workers`|Number of Spark workers to use for stitching one acquisition. Default: 4||`integer`
|`worker_cores`|Number of cores allocated to each Spark worker. Default: 4||`integer`
|`gb_per_core`|Size of memory (in GB) that is allocated for each core of a Spark worker. Default: 4|The total memory usage for stitching one acquisition will be workers *worker_cores* gb_per_core. |`integer`
|`driver_memory`|Amount of memory to allocate for the Spark driver. Default: 15g||`string`
|`wait_for_spark_timeout_seconds`|Number of seconds to wait for Spark cluster to start. Default: 3600||`integer`
|`sleep_between_timeout_checks_seconds`|Number of seconds to sleep between timeout checks. Default: 2||`integer`
|`stitching_app`|Path to the JAR file containing the stitching application. Default: /app/app.jar||`string`

## Registration

Options for the registration algorithm (Bigstream)

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`registration_output`|Output directory for registration results. Default: registration|This path is relative to `output_dir`.|`string`
|`aff_scale`|The scale level for affine alignments. Default: s3||`string`
|`def_scale`|The scale level for deformable alignments. Default: s2||`string`
|`spots_cc_radius`|Default: 8||`integer`
|`spots_spot_number`|Default: 2000||`integer`
|`ransac_cc_cutoff`|Default: 0.9||`number`
|`ransac_dist_threshold`|Default: 2.5||`number`
|`deform_iterations`|Default: 500x200x25x1||`string`
|`deform_auto_mask`|Default: 0||`string`
|`registration_xy_stride`|The number of voxels along x/y for registration tiling. Default: 256|Must be power of 2.|`integer`
|`registration_xy_overlap`|Tile overlap on x/y axes|Defaults to registration_xy_stride/8 when not specified.|`integer`
|`registration_z_stride`|The number of voxels along z for registration tiling. Default: 256|Must be power of 2.|`integer`
|`registration_z_overlap`|Tile overlap on Z axes|Defaults to registration_z_stride/8 when not specified.|`integer`
|`ransac_cpus`|Number of CPU cores for RANSAC. Default: 1||`integer`
|`ransac_memory`|Amount of memory for RANSAC. Default: 1 G||`string`
|`spots_cpus`|Number of CPU cores for Spots step of registration. Default: 1||`string`
|`spots_memory`|Amount of memory for Spots step of registration. Default: 2 G||`string`
|`interpolate_cpus`|Number of CPU cores for Interpolate step of registration. Default: 1||`integer`
|`interpolate_memory`|Amount of memory for Interpolate step of registration. Default: 1 G||`string`
|`coarse_spots_cpus`|Number of CPU cores for Coarse Spots step of registration. Default: 1||`integer`
|`coarse_spots_memory`|Amount of memory for Coarse Spots step of registration. Default: 2 G||`string`
|`aff_scale_transform_cpus`|Number of CPU cores for Affine Scale Transform step of registration. Default: 1||`integer`
|`aff_scale_transform_memory`|Amount of memory for Affine Scale Transform step of registration. Default: 15 G||`string`
|`def_scale_transform_cpus`|Number of CPU cores for deformable scale registration. Default: 8||`integer`
|`def_scale_transform_memory`|Amount of memory for Deformable Scale Transform step of registration. Default: 80 G||`string`
|`deform_cpus`|Number of CPU cores for Deform step of registration. Default: 1||`integer`
|`deform_memory`|Amount of memory for Deform step of registration. Default: 10 G||`string`
|`registration_stitch_cpus`|Number of CPU cores for Stitch step of registration. Default: 2||`integer`
|`registration_stitch_memory`|Amount of memory for Stitch step of registration. Default: 20 G||`string`
|`registration_transform_cpus`|Number of CPU cores for final Transform step of registration. Default: 12||`integer`
|`registration_transform_memory`|Amount of memory for final Transform step of registration. Default: 80 G||`string`

## Cell Segmentation

Options for the cell segmentation algorithm (Starfinity)

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`segmentation_output`|Output directory for segmentation results. Default: segmentation|This path is relative to `output_dir`.|`string`
|`segmentation_scale`|Imagery scale to use for segmentation. Default: s2||`string`
|`segmentation_cpus`|Number of CPU cores for segmentation. Default: 3||`integer`
|`segmentation_memory`|Amount of memory for segmentation. Default: 45 G||`string`

## Spot Extraction

Options for spot extraction

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`spot_extraction_output`|Output directory for spot extraction results. Default: spots|This path is relative to `output_dir`.|`string`
|`spot_extraction_scale`|Scale of imagery to use for spot extraction. Default: s0||`string`

## Spot Extraction: Airlocalize

Options for the AirLocalize spot extraction algorithm

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`airlocalize_xy_stride`|The number of voxels along x/y for registration tiling. Default: 1024|Must be power of 2. Increasing this requires increasing `airlocalize_memory`.|`integer`
|`airlocalize_xy_overlap`|Tile overlap on x/y axes|Defaults to 5% of airlocalize_xy_stride|`integer`
|`airlocalize_z_stride`|The number of voxels along Z for registration tiling.  Default: 512|Must be a power of 2. Increasing this requires increasing `airlocalize_memory`.|`integer`
|`airlocalize_z_overlap`|Tile overlap on z axes|Defaults to 5% of airlocalize_z_stride|`integer`
|`default_airlocalize_params`|Path to the default AirLocalize parameter file. Default: /app/airlocalize/params/air_localize_default_params.txt|By default, this points to default parameters inside the container|`string`
|`per_channel_air_localize_params`|Comma-delimited paths to alternative AirLocalize parameter files, one per channel.|If you have 4 channels, and you are extracting spots from c0, c1, and c3, this parameter should look like this: `/path/to/params_c0.txt,/path/to/params_c1.txt,,/path/to/params_c3.txt`. Note the double comma to denote the empty file for c2, which should not be processed.|`string`
|`airlocalize_cpus`|Number of CPU cores to allocate for each AirLocalize job. Default: 1||`integer`
|`airlocalize_memory`|Amount of RAM to allocate to each AirLocalize job. Needs to be increased when increasing strides. Default: 2 G||`integer`

## Spot Extraction: RS-FISH

Options for the RS-FISH spot extraction algorithm

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`use_rsfish`|Use RS-FISH instead of AirLocalize for Spot Extraction. Default: false||`boolean`
|`rsfish_min`|Minimal intensity of the image. Default: 0||`integer`
|`rsfish_max`|Maximal intensity of the image. Default: 4096||`integer`
|`rsfish_anisotropy`|The anisotropy factor. Default: 0.7|Scaling of z relative to xy. Can be determined using the RS-FISH anisotropy plugin in Fiji.|`number`
|`rsfish_sigma`|Sigma value for Difference-of-Gaussian (DoG) calculation. Default 1.5||`number`
|`rsfish_threshold`|Threshold value for Difference-of-Gaussian (DoG) calculation. Default: 0.007||`number`
|`rsfish_background`|Background subtraction method, 0 == None, 1 == Mean, 2==Median, 3==RANSAC on Mean, 4==RANSAC on Median. Default: 0 (None)||`integer`
|`rsfish_intensity`|Intensity calculation method, 0 == Linear Interpolation, 1 == Gaussian fit (on inlier pixels), 2 == Integrate spot intensities (on candidate pixels). Default: 0 (Linear Interpolation)||`integer`
|`rsfish_params`|Any other parameters to pass to the RS-FISH algorithm.|Complete parameter documentation for RS-FISH is [available here](https://github.com/PreibischLab/RS-FISH-Spark/blob/main/src/main/java/net/preibisch/rsfish/spark/SparkRSFISH.java).|`string`
|`rsfish_workers`|Number of Spark workers to use for RS-FISH spot detection. Default: 4||`integer`
|`rsfish_worker_cores`|Number of cores allocated to each RS-FISH Spark worker. Default: 4||`integer`
|`rsfish_gb_per_core`|Size of memory (in GB) that is allocated for each core of a RS-FISH Spark worker. Default: 4|The total memory usage for one acquisition will be workers *worker_cores* gb_per_core.|`integer`
|`rsfish_driver_cores`|Number of cores allocated for the RS-FISH Spark driver. Default: 1||`string`
|`rsfish_driver_memory`|Amount of memory to allocate for the RS-FISH Spark driver. Default: 15g||`string`

### Per channel RS-FISH Parameters

The following parameters can be set per channel: `rsfish_min`, `rsfish_max`, `rsfish_anisotropy`, `rsfish_sigma`, `rsfish_threshold`, `rsfish_background`, `rsfish_intensity`. Simply prefix the corresponding parameter with `per_channel.` and set the values using a comma delimited list. The values will be associated with the corresponding channel based on their position, i.e. first value will be associated with the first channel, second with the second channel, etc. If a value is missing or empty the parameter value for the channel will be set to the default from the parameter with the same name (presented above).

For example if the command like is:
`--channels c0,c1,c2,c3 --sigma 1.7 --per_channel.sigma "1.2,,1.4`

channel c0 will use sigma 1.2

channel c1 will use the default sigma 1.7 (because of the empty value)

channel c2 will use sigma 1.4

channel c3 will use the default sigma 1.7 (because of the missing value - sigma values list is shorter then the channels list)

## Spot Warping

Options for warping detected spots to registration

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`warp_spots_cpus`|Number of CPU cores to use for warp spots. Default: 2||`integer`
|`warp_spots_memory`|Amount of memory for warp spots. Default: 30 G||`string`

## Intensity Measurement

Options for extracting quantified measurements of spot intensities

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`measure_intensities_output`|Output directory for intensities. Default: intensities|This path is relative to `output_dir`.|`string`
|`measure_intensities_cpus`|Number of CPU cores to use for intensity measurement. Default: 1||`integer`
|`measure_intensities_memory`|Amount of memory for intensity measurement. Default: 8 G||`string`

## Spot Assignment

Options for mapping spot counts to segmented cells

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`assign_spots_output`|Output directory for spot assignments. Default: assignments|This path is relative to `output_dir`.|`string`
|`assign_spots_cpus`|Number of CPU cores to use for spot assignment. Default: 1||`integer`
|`assign_spots_memory`|Amount of memory for spot assignment. Default: 5 G||`string`

## Container Options

Customize the Docker containers used for each pipeline step

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`mfrepo`|Docker registry/repository to use for containers. Default: janeliascicomp|By default, the pipeline uses containers built as part of this project and deployed to DockerHub. You can rebuild the containers and deploy them to your own Registry and specify it here.|`string`
|`spark_container_repo`|Docker container repo for stitching. Default: `<mfrepo>`||`string`
|`spark_container_name`|Docker container name for stitching. Default: stitching||`string`
|`spark_container_version`|Docker container version for stitching. Default: 1.0.0||`string`
|`registration_container`|Docker container for running registration and warp_spots. Default: `<mfrepo>`/registration:1.2.0||`string`
|`segmentation_container`|Docker container for running segmentation. Default: `<mfrepo>`/segmentation:1.0.0||`string`
|`airlocalize_container`|Docker container for running spot extraction. Default: `<mfrepo>`/airlocalize:1.0.2||`string`
|`spots_assignment_container`|Docker container for running intensity measurement and spot assignment. Default: `<mfrepo>`/spot_assignment:1.2.0||`string`

## Other Options

Other global options affecting all pipelines stages

|Parameter|Description|Help Text|Type
|-----------|-----------|-----------|-----------
|`skip`|Comma-delimited list of steps to skip, e.g. stitching,registration.|Valid values: stitching,spot_extraction,segmentation,registration,warp_spots,measure_intensities,assign_spots|`string`
|`singularity_cache_dir`|Shared directory where Singularity containers are cached. Default: $shared_work_dir/singularity_cache or $HOME/.singularity_cache||`string`
|`singularity_user`|User to use for running Singularity containers. Default: $USER|This is automatically set to `ec2-user` when using the 'tower' profile|`string`
|`runtime_opts`|Runtime options for the container engine being used (e.g. Singularity or Docker).|Runtime options for Singularity must include mounts for any directory paths you are using. You can also pass the --nv flag here to make use of NVIDIA GPU resources. For example, `--nv -B /your/data/dir -B /your/output/dir`
|`string`
|`lsf_opts`|Options for LSF cluster at Janelia, when using the lsf profile.||`string`
