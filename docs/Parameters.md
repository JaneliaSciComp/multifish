# Parameters

The pipeline supports many types of parameters for customization to your compute environment and data. These can all be specified on the command line using the standard syntax `--argument="value"` or `--argument "value"`. You can also use any option supported by Nextflow itself. Note that certain arguments (i.e. those interpreted by Nextflow) use a single dash instead of two.

## Global Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --data_dir | | Path to the directory containing the input CZI/MVL acquisition files | 
| --output_dir | | Path to the directory containing pipeline outputs |
| &#x2011;&#x2011;segmentation_model_dir | | Path to the directory containing the machine learning model for segmentation |
| --acq_names | | Names of acquisition rounds to process. These should match the names of the CZI/MVL files found in the data_dir. |  
| --ref_acq | | Name of the acquisition round to use as the fixed reference |
| --skip | | Comma-delimited list of steps to skip, e.g. "stitching,registration" (Valid values: stitching, spot_extraction, segmentation, registration, warp_spots, intensities, assign_spots) |
| --runtime_opts | | Runtime options for Singularity must include mounts for any directory paths you are using. You can also pass the --nv flag here to make use of NVIDIA GPU resources. For example, `--nv -B /your/data/dir -B /your/output/dir` | 
| --workdir | ./work | Nextflow working directory where all intermediate files are saved |
| --mfrepo | janeliascicomp (on DockerHub) | Docker Registry and Repository to use for containers | 
| -profile | localsingularity | Configuration profile to use (Valid values: localsingularity, lsf) |
| -with-tower | | [Nextflow Tower](https://tower.nf) URL for monitoring |

## Stitching Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --stitching_app | external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar | Path to the JAR file containing the stitching application. This is built by the `setup.sh` script run in *Quick Start* above. |
| --stitching_output | stitching | Output directory for stitching (relative to --output_dir) |
| --resolution | 0.23,0.23,0.42 | |
| --axis | -x,y,z | Axis mapping for objective to pixel coordinates conversion when parsing CZI metadata. Minus sign flips the axis. |
| --channels | c0,c1,c2,c3 | List of channels to stitch |
| --stitching_block_size | 128,128,64 | Block size to use when converting CZI to n5 before stitching |
| --retile_z_size | 64 | Block size (in Z dimension) when retiling after stitching. This must be smaller than the number of Z slices in the data. |
| --stitching_ref | 2 | Index of the channel used for stitching; if this is not defined it defaults to dapi_channel |
| --stitching_mode | incremental | |
| --stitching_padding | 0,0,0 | |
| &#x2011;&#x2011;stitching_blur_sigma | 2 | |
| --workers | 4 | Number of Spark workers to use for stitching one acquisition |
| --worker_cores | 4 | Number of cores allocated to each Spark worker |
| --gb_per_core | 15 | Size of memory (in GB) that is allocated for each core of a Spark worker. The total memory usage for stitching one acquisition will be workers * worker_cores * gb_per_core. | 
| --driver_memory | 15g | Amount of memory to allocate for the Spark driver |

## Spot Extraction Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spot_extraction_container | \<mfrepo\>/spotextraction:1.0.0 | Docker container to use for running spot extraction |
| --spot_extraction_output | spots | Output directory for spot extraction (relative to --output_dir) |
| --dapi_channel | c2 | DAPI channel |
| --bleed_channel | c3 | Channel (other than DAPI) used to correct bleedthrough on DAPI channel |
| --spot_extraction_scale | s0 | Scale of imagery to use for spot extraction |
| --spot_extraction_xy_stride | 1024 | The number of voxels along x/y for registration tiling, must be power of 2. Increasing this requires increasing the memory allocation. |
| --spot_extraction_xy_overlap | 5% of xy_stride | Tile overlap on x/y axes |
| --spot_extraction_z_stride | 512 | The number of voxels along z for registration tiling, must be power of 2. Increasing this requires increasing the memory allocation. |
| --spot_extraction_z_overlap | 5% of z_stride | Tile overlap on z axis |
| --default_airlocalize_params | /app/airlocalize/params/air_localize_default_params.txt | Path to hAirLocalize parameter file. By default, this points to default parameters inside the container. |
| &#x2011;&#x2011;per_channel_air_localize_params | ,,, | Paths to alternative airlocalize parameter files, one per channel |
| --spot_extraction_cpus | 2 | Number of CPU cores to allocate for each hAirlocalize job |
| --spot_extraction_memory | 30 | Amount of RAM (in GB) to allocate to each hAirlocalize job. Needs to be increased when increasing strides. |

### Segmentation Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --segmentation_container | \<mfrepo\>/segmentation:1.0.0 | Docker container to use for running segmentation |
| --segmentation_output | segmentation | Output directory for segmentation (relative to --output_dir) |
| &#x2011;&#x2011;segmentation_model_dir | | Starfinity for segmentation |
| --dapi_channel | c2 | DAPI channel | 
| --segmentation_scale | s2 | Imagery scale to use for segmentation |
| --segmentation_cpus | 3 | Number of CPU cores to allocate for segmentation |

## Registration Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --registration_container | \<mfrepo\>/registration:1.1.0 | Docker container to use for running registration and warp_spots |
| --registration_output | registration | Output directory for registration (relative to --output_dir) | 
| --dapi_channel | c2 | DAPI channel | 
| --aff_scale | s3 | The scale level for affine alignments |
| --def_scale | s2 | The scale level for deformable alignments |
| --spots_cc_radius | 8 | |
| --spots_spot_number | 2000 | |
| --ransac_cc_cutoff | 0.9 | |
| --ransac_dist_threshold | 2.5 | |
| --deform_iterations | 500x200x25x1 | |
| --deform_auto_mask | 0 | |
| --registration_xy_stride | 256 | The number of voxels along x/y for registration tiling, must be power of 2 |
| --registration_xy_overlap | xy_stride/8 | Tile overlap on x/y axes |
| --registration_z_stride | 256 | The number of voxels along z for registration tiling, must be power of 2 | 
| --registration_z_overlap | z_stride/8 | Tile overlap on z axis |
| --aff_scale_transform_cpus | 1 | Number of CPU cores for affine scale registration |
| --def_scale_transform_cpus | 8 | Number of CPU cores for deformable scale registration  |
| --registration_stitch_cpus | 2 | Number of CPU cores for re-stitching registered tiles  |
| &#x2011;&#x2011;registration_transform_cpus | 12 | Number of CPU cores for final registered transform |

## Spot Warping Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| &#x2011;&#x2011;registration_container | \<mfrepo\>/registration:1.0.0 | Docker container to use for running registration and warp_spots |
| --warp_spots_cpus | 2 | Number of CPU cores to use for warp spots | 

## Intensity Measurement Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| &#x2011;&#x2011;spots_assignment_container | \<mfrepo\>/spot_assignment:1.0.0 | Docker container to use for running intensities and spot_assignment |
| --measure_intensities_output | intensities | Output directory for intensities (relative to --output_dir) | 
| --dapi_channel | c2 | DAPI channel | 
| --bleed_channel | c3 | | 
| --measure_intensities_cpus | 1 | Number of CPU cores to use for intensity measurement | 

## Spot Assignment Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| &#x2011;&#x2011;spots_assignment_container | \<mfrepo\>/spot_assignment:1.0.0 | Docker container to use for running intensities and spot_assignment |
| --assign_spots_output | assignments | Output directory for spot assignments (relative to --output_dir) |
| --assign_spots_cpus | 1 | Number of CPU cores to use for spot assignment |
