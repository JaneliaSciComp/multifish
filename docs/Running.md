---
layout: default
nav_order: 5
---

# Running the pipeline

## Specifying inputs

The pipeline accepts a parameter called `shared_work_dir` which points to a directory where the pipeline will read inputs, store intermediate results, and write final outputs. This directory is shared (e.g. accessible) between the pipeline and the cluster. The shared work directory is organized like this:

    shared_work_dir/
        inputs/
            ...
        outputs/
            ...
        spark/
            ...

You should create the top level directory before running the pipeline.  

The pipeline accepts CZI/MVL files as input, so the first step is to point it to your input data. There are two ways to do this:

### Option 1 - Use a data manifest

The demo scripts under `./examples` use the `data_manifest` parameter to download an input data set. In this case, the *shared_work_dir/inputs* directory will be automatically created and populated with the data. If the data has been downloaded in the past, the download will be skipped and the files will be verified using MD5 checksums.

You can use this method for your own custom data as well, especially if you have small data sets that you wish to run repeatedly for benchmarking or reproducibility. The data manifest is a simple text file that lists the files in the data set, their MD5 sums, and HTTP links to download them. Create your manifest file and point the pipeline to it with the `data_manifest` parameter. You can use `verify_md5=false` to skip the MD5 checksum verification for faster iteration.

### Option 2 - Place data manually

For larger custom data, it's recommended that you place it in the `inputs` directory manually. Your CZI and MVL files should be paired by name, e.g.:

    shared_work_dir/
        inputs/
            LHA3_R3_small.czi
            LHA3_R3_small.mvl
            LHA3_R5_small.czi
            LHA3_R5_small.mvl

In this case, you don't need to provide a `data_manifest` parameter. The default for this parameter is "segmentation", which downloads just the segmentation model and places it in the `inputs` directory, next to your data.

## Setting parameters

See the [parameter documentation](Parameters.md) to customize the pipeline for your data.

## Starting the pipeline

### Using Nextflow Tower

See the [Nextflow Tower](tower/NextflowTower.html) documentation for step-by-step instructions on how to run the pipeline from the Nextflow Tower web GUI.

### Using the Command Line Interface (CLI)

Assuming you have two acquisitions as above (i.e. named `LHA3_R3_small` and `LHA3_R5_small`), you can run the pipeline with the following command:

    ./main.nf --shared_work_dir /path/to/shared/work/dir --runtime_opts "-B /path/to/shared/work/dir" --acq_names LHA3_R3_small,LHA3_R5_small --ref_acq LHA3_R3_small --channels c0,c1 --dapi_channel c1 [other parameters]

This will run the pipeline and execute all of the jobs on the local workstation where you invoke the command. To use a cluster or cloud for executing the jobs, see the [Platforms documentation](platforms/Platforms.md).

The `--runtime_opts` parameter is required to mount the shared work directory inside the Singularity containers that are used to execute the pipeline jobs. The `--acq_names` parameter is required to specify the names of the acquisitions to process. The `--ref_acq` parameter is required to specify the name of the reference acquisition. The `--channels` parameter specifies the names of the channels to process in each acquisition. The `--dapi_channel` parameter is used to specify the name of the channel that contains the DAPI stain.

## Pipeline outputs

The output directory contains one folder each acquisition in `--acq_names`. Under each acquisition directory, you'll find a folder for each step in the pipeline that was applied to that round.

    LHA3_R3_tiny
      assignments
      intensities
      segmentation
      spots
      stitching

    LHA3_R5_tiny
      assignments
      intensities
      registration
      spots
      stitching

In this case, the pipeline was run on two acquisitions, `LHA3_R3_medium` and `LHA3_R5_medium`. The stitching step was run on both acquisitions. Then the `LHA3_R3_medium` was segmented and the `LHA3_R5_medium` was registered to the `LHA3_R3_medium`. Finally, spot extraction, intensity measurement, and cell assignment were all run on both acquisitions.

### Stitching Output

The output of the stitching step includes many intermediate files that can be used for debugging and verification of the results.

* **tiles.json** - multi-view metadata about the acquisition converted from the MVL file
* **tiles.n5** - imagery converted from CZI to [n5 format](https://github.com/saalfeldlab/n5) tiled according to `--stitching_block_size`
* **c\<channel\>-n5.json** - metadata about each channel in tiles.n5
* **c\<channel\>-flatfield** - files for flatfield-correction including the calculated brightfield and offset
* **c\<channel\>-n5-retiled.json** - metadata after retiling
* **retiled-images** - retiled images
* **optimizer-final.txt** - stitching log
* **c\<channel\>-n5-retiled-final.json** - metadata output of stitching
* **export.n5** - final stitched result, tiled according to `--retile_z_size`

Full details about the stitching pipeline [are available here](https://github.com/saalfeldlab/stitching-spark).

### Segmentation

The segmentation directory contains a single TIFF file with the cell segmentation result.

### Registration

The registration directory contain a `<moving>-to-<fixed>` directory, e.g `LHA3_R5_medium-to-LHA3_R3_medium`. Inside that folder:

* **tiles** - tile-specific intermediate files
* **aff** - result of RANSAC affine alignment
* **transform** - registration transform (n5 format)
* **invtransform** - inverse of registration transform (n5 format)
* **warped** - final registered imagery (n5 format)

### Spots

If you use AirLocalize, you'll get this output:

* **tiles** - n5 formatted stack retiled for spot extraction
* **spots_CH.txt** - Per channel CSV file containing the spots found in that channel. This is a CSV file containing coordinates of the spots, in microns. This file is used for downstream analysis (e.g. cell assignment).
* **spots_airlocalize_CH.csv** - Per channel CSV file containing voxel coordinates of the spots found in channel 0. This file is compatible with the [RS-FISH Fiji Plugin](modules/RS-FISH.md).

If you use RS-FISH, you'll get this output:

* **spots_CH.txt** - Per channel CSV file containing the spots found in that channel. This is a CSV file containing coordinates of the spots, in microns. This file is used for downstream analysis (e.g. cell assignment).
* **spots_rsfish_CH.csv** - Per channel CSV file containing voxel coordinates of the spots found in channel 0. This file is compatible with the [RS-FISH Fiji Plugin](modules/RS-FISH.md).

### Intensities

Per channel CSV file containing intensities of each segmented cell ("ROI").

### Assignments

Single CSV file where the first column is an index into the cell segmentation, and the other columns represent the number of points found in that cell in each channel.
