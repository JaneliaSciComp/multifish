# EASI-FISH Nextflow Pipeline

The purpose of this pipeline is to analyze imagery collected using [EASI-FISH](https://github.com/multiFISH/EASI-FISH) (Expansion-Assisted Iterative Fluorescence *In Situ* Hybridization). It includes automated image stitching, distributed multi-round image registration, cell segmentation, and distributed spot detection. 

This pipeline is containerized and portable across the various platforms supported by [Nextflow](https://www.nextflow.io). So far it has been tested on a standalone workstation and the Janelia compute cluster (IBM Platform LSF). If you run it successfully on any other platform, please let us know so that we can update this documentation.

The pipeline includes the following modules:
* **stitching** - Spark-based distributed stitching pipeline
* **spot_extraction** - Spot detection using hAirlocalize
* **segmentation** - Cell segmentation using Starfinity 
* **registration** - Bigstream distributed registration pipeline
* **warp_spots** - Warp detected spots to registration
* **intensities** - Intensity measurement
* **assign_spots** - Mapping of spot counts to segmented cells

![Pipeline Diagram](docs/pipeline_diagram.png)

Further documentation about the individual pipeline steps is available in the [EASI-FISH](https://github.com/multiFISH/EASI-FISH) repo.


## Prerequisites

The only software requirements for running this pipeline are [Nextflow](https://www.nextflow.io) and [Singularity](https://sylabs.io). If you are running in an HPC cluster, [Singularity](https://sylabs.io) must be installed on all the cluster nodes. 

## Quick Start

Clone this repo with the following command:

    git clone git@github.com:JaneliaSciComp/multifish.git

Before running the pipeline for the first time, pull in and build the submodules using the setup script:

    ./setup.sh
  
Launch the demo using the EASI-FISH example data:

    ./examples/demo.sh <data dir> [arguments]

The `data dir` is the path where you want to store the data and analysis results. 

You can also add additional arguments to the end in order to, for example, skip steps previously completed, or add Nextflow Tower monitoring. See below for additional details about the argument usage.


## Parameters

### Global Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --data_dir | | Path to the directory containing the input CZI/MVL acquisition files | 
| --output_dir | | Path to the directory containing pipeline outputs |
| &#x2011;&#x2011;segmentation_model_dir | | Path to the directory containing the machine learning model for segmentation |
| --acq_names | | Names of acquisition rounds to process. These should match the names of the CZI/MVL files found in the data_dir. |  
| --ref_acq | | Name of the acquisition round to use as the fixed reference |
| --skip | | Comma-delimited list of steps to skip, e.g. "stitching,registration" (Valid values: stitching, spot_extraction, segmentation, registration, warp_spots, intensities, assign_spots) |
| --workdir | ./work | Nextflow working directory where all intermediate files are saved |
| --mfrepo | janeliascicomp (on DockerHub) | Docker Registry and Repository to use for containers | 
| -profile | localsingularity | Configuration profile to use (Valid values: localsingularity, lsf) |
| -with-tower | | [Nextflow Tower](https://tower.nf) URL for monitoring |

### Stitching Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --stitching_app | external-modules/stitching-spark/target/stitching-spark-1.8.2-SNAPSHOT.jar | Path to the JAR file containing the stitching application. This is built by the `setup.sh` script run in *Quick Start* above. |
| --stitching_output | stitching | Output directory for stitching (relative to --output_dir) |
| --resolution | 0.23,0.23,0.42 | |
| --axis | -x,y,z | Axis mapping for objective to pixel coordinates conversion when parsing CZI metadata. Minus sign flips the axis. |
| --channels | c0,c1,c2,c3 | List of channels to stitch |
| --block_size | 128,128,64 | Block size to use when converting CZI to n5 before stitching |
| --retile_z_size | 64 | Block size (in Z dimension) when retiling after stitching. This must be smaller than the number of Z slices in the data. |
| --stitching_ref | 2 | Index of the channel used for stitching |
| --stitching_mode | incremental | |
| &#x2011;&#x2011;stitching_padding | 0,0,0 | |
| --blur_sigma | 2 | |
| --workers | 4 | Number of Spark workers to use for stitching one acquisition |
| --worker_cores | 4 | Number of cores allocated to each Spark worker |
| --gb_per_core | 15 | Size of memory (in GB) that is allocated for each core of a Spark worker. The total memory usage for stitching one acquisition will be workers * worker_cores * gb_per_core. | 
| --driver_memory | 15g | Amount of memory to allocate for the Spark driver |

### Spot Extraction Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spotextraction_container | \<mfrepo\>/spotextraction:1.0 | Docker container to use for running spot extraction |
| --spot_extraction_output | spots | Output directory for spot extraction (relative to --output_dir) |
| --scale_4_spot_extraction | s0 | |
| --spot_extraction_xy_stride | 1024 | The number of voxels along x/y for registration tiling, must be power of 2. Increasing this requires increasing the memory allocation. |
| --spot_extraction_xy_overlap | 5% of xy_stride | Tile overlap on x/y axes |
| --spot_extraction_z_stride | 512 | The number of voxels along z for registration tiling, must be power of 2. Increasing this requires increasing the memory allocation. |
| --spot_extraction_z_overlap | 5% of z_stride | Tile overlap on z axis |
| &#x2011;&#x2011;spot_extraction_dapi_correction_channels | | |
| --default_airlocalize_params | /app/airlocalize/params/air_localize_default_params.txt | Path to hAirLocalize parameter file. By default, this points to default parameters inside the container. |
| --per_channel_air_localize_params | ,,, | |
| --spot_extraction_cpus | 2 | Number of CPU cores to allocate for each hAirlocalize job |
| --spot_extraction_memory | 30 | Amount of RAM (in GB) to allocate to each hAirlocalize job. Needs to be increased when increasing strides. |

### Segmentation Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --segmentation_container | \<mfrepo\>/segmentation:1.0 | Docker container to use for running segmentation |
| --dapi_channel | c2 | DAPI channel used to drive both the segmentation and the registration | 
| &#x2011;&#x2011;segmentation_model_dir | | |
| --segmentation_output | segmentation | |
| --scale_4_segmentation | s2 | |
| --segmentation_model_dir | | |
| --predict_cpus | 3 | |

### Registration Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --registration_container | \<mfrepo\>/registration:1.0 | Docker container to use for running registration and warp_spots |
| --dapi_channel | c2 | DAPI channel used to drive both the segmentation and the registration | 
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
| &#x2011;&#x2011;def_scale_transform_cpus | 8 | Number of CPU cores for deformable scale registration  |
| --stitch_registered_cpus | 2 | Number of CPU cores for re-stitching registered tiles  |
| --final_transform_cpus | 12 | Number of CPU cores for final registered transform |

### Spot Warping Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --registration_container | \<mfrepo\>/registration:1.0 | Docker container to use for running registration and warp_spots |
| --warp_spots_cpus | 2 | Number of CPU cores to use for warp spots | 

### Intensity Measurement Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spots_assignment_container | \<mfrepo\>/spot_assignment:1.0 | Docker container to use for running intensities and spot_assignment |
| --intensities_output | intensities | Output directory for intensities (relative to --output_dir) | 
| --bleed_channel | c3 | | 
| --intensity_cpus | 1 | Number of CPU cores to use for intensity measurement | 

### Spot Assignment Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spots_assignment_container | \<mfrepo\>/spot_assignment:1.0 | Docker container to use for running intensities and spot_assignment |
| --assign_spots_output | assignments | Output directory for spot assignments (relative to --output_dir) |
| --assignment_cpus | 1 | Number of CPU cores to use for spot assignment

## Pipeline Execution

Nextflow supports many different execution engines for portability across platforms and schedulers. We have tested the pipeline using local execution and using the cluster at Janelia Research Campus (running IBM Platform LSF). 

To run this pipeline on a cluster, all input and output paths must be mounted and accessible on all the cluster nodes. 

### Run the pipeline locally

To run the pipeline locally, you can use the standard profile:

    ./main.nf [arguments]

This is equivalent to specifying the localsingularity profile:

    ./main.nf -profile localsingularity [arguments]

### Run the pipeline on IBM Platform LSF 

This example also sets the project flag to demonstrate how to set LSF options.

    ./main.nf -profile lsf --lsf_opts "-P multifish" [arguments]

Complete examples are available in the [examples](examples) directory.

## Troubleshooting

### Temporary Files

The pipeline downloads Docker containers and converts them into Singularity Image Format prior to execution. This requires about 10 GB of tmp space. In addition, other parts of the pipeline also use the temp directory while running, for example for MATLAB's MCR_CACHE_ROOT.

If the filesystem containing your /tmp directory does not have sufficient space for downloading and extracting the Docker containers, you will need to point both `TMPDIR` and `SINGULARITY_TMPDIR` to an alternate location, e.g.

    export TMPDIR=/opt/tmp
    export SINGULARITY_TMPDIR=$TMPDIR

If you do this, make sure to mount this directory into the containers using the `-B` option:

    --runtime_opts "-B $TMPDIR"


## Development

If you are a software developer wishing to contribute bug fixes or features, please refer to the [Development docs](docs/Development.md).
