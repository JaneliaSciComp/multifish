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
| TMPDIR | /tmp | Directory used for temporary files by certain processes. |
| SINGULARITY_TMPDIR | /tmp | Directory where Docker images are downloaded and converted to Singularity Image Format. Needs to be large enough to accommodate several GB, so moving it out of /tmp is sometimes necessary. |

## Global Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --skip | | Comma-delimited list of steps to skip, e.g. "stitching,registration" (Valid values: stitching, spot_extraction, segmentation, registration, warp_spots, measure_intensities, assign_spots) |
| --singularity_cache_dir | $HOME/.singularity_cache | Shared directory where Singularity containers are cached. Default: $shared_work_dir/singularity_cache or $HOME/.singularity_cache |
| --singularity_user | $USER | User to use for running Singularity containers. This is automatically set to `ec2-user` when using the 'tower' profile.  |
| --runtime_opts | | Runtime options for Singularity must include mounts for any directory paths you are using. You can also pass the --nv flag here to make use of NVIDIA GPU resources. For example, `--nv -B /your/data/dir -B /your/output/dir` |
| -workdir | ./work | Nextflow working directory where all intermediate files are saved |
| -profile | localsingularity | Configuration profile to use (Valid values: localsingularity, lsf) |
| -with-tower | | [Nextflow Tower](https://tower.nf) URL for monitoring |

## Data Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --data_manifest | | Name or path to the file manifest for downloading input data. If specified, the data in the manifest is downloaded into `--data_dir` before the pipeline begins. Valid values are any filename found in the data-sets directory (e.g. "demo_small", "demo_medium") or any path which points to a manifest file. |
| --verify_md5 | true |  Verify MD5 sum for all downloads. This can be disabled to save time, but it's not recommended. |
| --shared_work_dir | | Shared working directory accessible by all nodes. Setting this parameter will automatically configure `data_dir`, `output_dir`, `segmentation_model_dir`, `spark_work_dir`, and `singularity_cache_dir` relative to this directory. |
| --data_dir | | Path to the directory containing the input CZI/MVL acquisition files. If shared_work_dir is defined, this defaults to $shared_work_dir/inputs. If `shared_work_dir` is defined, this is automatically set to `$shared_work_dir/inputs`. |
| &#x2011;&#x2011;segmentation_model_dir | | Path to the directory containing the machine learning model for segmentation. If `shared_work_dir` is defined, this is automatically set to `$shared_work_dir/inputs/model/starfinity`. It is assumed that either the model is already there, or it will be downloaded and unzipped according to the `data_manifest`. Otherwise it defaults to ${projectDir}/external-modules/segmentation/model/starfinity, which is normally configured by setup.sh. |
| --output_dir | | Path to the directory containing pipeline outputs |
| --publish_dir | | Optional publishing directory where results should be copied when the pipeline is successfully completed. This is useful when running in the cloud, e.g. for getting data off of FSx and onto something externally accessible like S3. Typically a Fusion mount path like /fusion/s3/bucket-name. |
| --acq_names | | Names of acquisition rounds to process. These should match the names of the CZI/MVL files found in the data_dir. e.g. LHA3_R3_small,LHA3_R5_small if you have files called LHA3_R3_small.czi and LHA3_R5_small.czi. |  
| --ref_acq | | Name of the acquisition round to use as the fixed reference. e.g. LHA3_R3_small |
| --channels | c0,c1,c2,c3 | List of channel names to process. Channel names are specified in the format "c[channel_number]", where the channel_number is 0-indexed. |
| --dapi_channel | c2 | Name of the DAPI channel. The DAPI channel is used as a reference channel for registration, segmentation, and spot extraction. |
| --bleed_channel | c3 | Channel (other than DAPI) used to correct bleed-through on DAPI channel |

## Stitching Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --stitching_app | external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar | Path to the JAR file containing the stitching application. This is built by the `setup.sh` script run in *Quick Start* above. |
| --stitching_output | stitching | Output directory for stitching (relative to --output_dir) |
| --spark_work_dir | | Path to directory containing Spark working files and logs during stitching |
| --stitching_czi_pattern | | A suffix pattern that is applied to acq_names when creating CZI names e.g. "_V%02d" |
| --resolution | 0.23,0.23,0.42 | |
| --axis | -x,y,z | Axis mapping for objective to pixel coordinates conversion when parsing CZI metadata. Minus sign flips the axis. |
| --stitching_block_size | 128,128,64 | Block size to use when converting CZI to n5 before stitching |
| --retile_z_size | 64 | Block size (in Z dimension) when retiling after stitching. This must be smaller than the number of Z slices in the data. |
| --stitching_ref | 2 | Index of the channel used for stitching; if this is not defined it defaults to dapi_channel |
| --stitching_mode | incremental | |
| --stitching_padding | 0,0,0 | |
| &#x2011;&#x2011;stitching_blur_sigma | 2 | |
| --workers | 4 | Number of Spark workers to use for stitching one acquisition |
| --worker_cores | 4 | Number of cores allocated to each Spark worker |
| --gb_per_core | 15 | Size of memory (in GB) that is allocated for each core of a Spark worker. The total memory usage for stitching one acquisition will be workers *worker_cores* gb_per_core. |
| --driver_memory | 15g | Amount of memory to allocate for the Spark driver |

## Spot Extraction Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spot_extraction_output | spots | Output directory for spot extraction (relative to --output_dir) |
| --spot_extraction_scale | s0 | Scale of imagery to use for spot extraction |

## Airlocalize Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --airlocalize_xy_stride | 1024 | The number of voxels along x/y for registration tiling, must be power of 2. Increasing this requires increasing the memory allocation. |
| --airlocalize_xy_overlap | 5% of xy_stride | Tile overlap on x/y axes |
| --airlocalize_z_stride | 512 | The number of voxels along z for registration tiling, must be power of 2. Increasing this requires increasing the memory allocation. |
| --airlocalize_z_overlap | 5% of z_stride | Tile overlap on z axis |
| --default_airlocalize_params | /app/airlocalize/params/air_localize_default_params.txt | Path to hAirLocalize parameter file. By default, this points to default parameters inside the container. |
| &#x2011;&#x2011;per_channel_air_localize_params | ,,, | Paths to alternative airlocalize parameter files, one per channel |
| --airlocalize_cpus | 2 | Number of CPU cores to allocate for each hAirlocalize job |
| --airlocalize_memory | 30 G | Amount of RAM (in GB) to allocate to each hAirlocalize job. Needs to be increased when increasing strides. |

## RS-FISH Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --use_rsfish | false | Use RS-FISH instead of AirLocalize for Spot Extraction |
| --rsfish_min | 0 | Minimal intensity of the image |
| --rsfish_max | 4096 | Maximal intensity of the image |
| --rsfish_anisotropy | 0.7 | The anisotropy factor (scaling of z relative to xy, can be determined using the anisotropy plugin) |
| --rsfish_sigma | 1.5 | Sigma value for Difference-of-Gaussian (DoG) calculation |
| --rsfish_threshold | 0.007 | Threshold value for Difference-of-Gaussian (DoG) calculation |
| --rsfish_params | | Any other parameters to pass to the RS-FISH algorithm |
| --rsfish_workers | 1 | Number of Spark workers to use for RS-FISH spot detection |
| --rsfish_worker_cores | 8 | Number of cores allocated to each Spark worker |
| --rsfish_gb_per_core | 4 | Size of memory (in GB) that is allocated for each core of a Spark worker. The total memory usage for stitching one acquisition will be workers *worker_cores* gb_per_core.  |
| --rsfish_driver_cores | 1 | Number of cores to allocate for the Spark driver |
| --rsfish_driver_memory | 1g | Amount of memory to allocate for the Spark driver  |

### Segmentation Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --segmentation_output | segmentation | Output directory for segmentation (relative to --output_dir) |
| &#x2011;&#x2011;segmentation_model_dir | ./external-modules/segmentation/model/starfinity | Starfinity model for segmentation |
| --dapi_channel | c2 | DAPI channel |
| --segmentation_scale | s2 | Imagery scale to use for segmentation |
| --segmentation_cpus | 3 | Number of CPU cores to allocate for segmentation |
| --segmentation_memory | 45 G | Amount of memory to allocate for segmentation |

## Registration Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
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
| &#x2011;&#x2011;registration_transform_cpus | 12 | Number of CPU cores for final registered transform |
| --ransac_cpus | 1 | Number of CPU cores for RANSAC |
| --ransac_memory | 1 G | Amount of memory for RANSAC |
| --spots_cpus | 1 | Number of CPU cores for Spots step of registration |
| --spots_memory | 2 G | Amount of memory for Spots step of registration |
| --interpolate_cpus | 1 | Number of CPU cores for Interpolate step of registration |
| --interpolate_memory | 1 G | Amount of memory for Interpolate step of registration |
| --coarse_spots_cpus | 1 | Number of CPU cores for Coarse Spots step of registration |
| --coarse_spots_memory | 2 G | Amount of memory for Coarse Spots step of registration |
| --aff_scale_transform_cpus | 1 | Number of CPU cores for Affine Scale Transform step of registration |
| --aff_scale_transform_memory | 15 G | Amount of memory for Affine Scale Transform step of registration |
| --def_scale_transform_cpus | 8 | Number of CPU cores for Deformable Scale Transform step of registration |
| --def_scale_transform_memory | 80 G | Amount of memory for Deformable Scale Transform step of registration |
| --deform_cpus | 1 | Number of CPU cores for Deform step of registration |
| --deform_memory | 10 G | Amount of memory for Deform step of registration |
| --registration_stitch_cpus | 2 | Number of CPU cores for Stitch step of registration |
| --registration_stitch_memory | 20 G | Amount of memory for Stitch step of registration |
| --registration_transform_cpus | 12 | Number of CPU cores for final Transform step of registration |
| --registration_transform_memory | 80 G | Amount of memory for final Transform step of registration |

## Spot Warping Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --warp_spots_cpus | 2 | Number of CPU cores to use for warp spots |

## Intensity Measurement Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --measure_intensities_output | intensities | Output directory for intensities (relative to --output_dir) |
| --dapi_channel | c2 | DAPI channel |
| --bleed_channel | c3 | |
| --measure_intensities_cpus | 1 | Number of CPU cores to use for intensity measurement |

## Spot Assignment Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --assign_spots_output | assignments | Output directory for spot assignments (relative to --output_dir) |
| --assign_spots_cpus | 1 | Number of CPU cores to use for spot assignment |

## Container Options

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --mfrepo | janeliascicomp (on DockerHub) | Docker Registry and Repository to use for containers |
| --spark_container_repo | <mfrepo> | Docker container repo for stitching |
| --spark_container_name | stitching | Docker container name for stitching |
| --spark_container_version | 1.0.0 | Docker container version for stitching |
| --registration_container | \<mfrepo\>/registration:1.1.0 | Docker container to use for running registration and warp_spots |
| --segmentation_container | \<mfrepo\>/segmentation:1.0.0 | Docker container to use for running segmentation |
| --airlocalize_container | \<mfrepo\>/spotextraction:1.0.0 | Docker container to use for running spot extraction |
| &#x2011;&#x2011;spots_assignment_container | \<mfrepo\>/spot_assignment:1.0.0 | Docker container to use for running measure_intensities and spot_assignment |
| --rsfish_container_repo | <mfrepo> | Docker container repo for RS-FISH |
| --rsfish_container_name | rs_fish | Docker container name for RS-FISH |
| --rsfish_container_version | 1.0.0 | Docker container version for |
