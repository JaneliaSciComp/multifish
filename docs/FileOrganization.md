---
layout: default
nav_order: 15
---

# File Organization

The pipeline takes input from one directory (`--data_dir`) and generates output (including intermediate output files) in another directory (`--output_dir`).

## Data Dir

This directory is expected to contain a series of paired CZI/MVL files containing the imagery and metadata associated with a single round of MultiFISH imaging. For example, rounds 3 and 5 of the LHA imaging look like this:

    LHA3_R3_medium.czi
    LHA3_R3_medium.mvl
    LHA3_R5_medium.czi
    LHA3_R5_medium.mvl

Both `--acq_names` and `--ref_acq` contain names (without extensions) of files in this directory. To run the pipeline for both rounds, and keep rund 5 as fixed, you can use parameters `--acq_names="LHA3_R3_medium,LHA3_R5_medium" --ref_acq=LHA3_R5_medium`. This is demonstrated fully in `examples/demo.sh`.

## Output Dir

The output directory contains one folder each acquisition in `--acq_names`. Under each acquisition, you'll find a folder for each step in the pipeline that was applied to that round. 

    LHA3_R3_medium
      stitching
      segmentation
      registration
      intensities
      spots

    LHA3_R5_medium
      stitching
      segmentation
      registration
      intensities
      spots

### Stitching Output

The output of the stitching step includes many intermediate files that can be used for debugging and verification of the results. 

* **tiles.json** - multiview metadata about the acquisition converted from the MVL file
* **tiles.n5** - imagery converted from CZI to [https://github.com/saalfeldlab/n5](n5 format) tiled according to `--stitching_block_size`
* **c\<channel\>-n5.json** - metadata about each channel in tiles.n5
* **c\<channel\>-flatfield** - files for flatfield-correction including the calculated brightfield and offset
* **c\<channel\>-n5-retiled.json** - metadata after retiling 
* **retiled-images** - retiled images
* **optimizer-final.txt** - stitching log
* **c\<channel\>-n5-retiled-final.json** - metadata output of stitching 
* **export.n5** - final stitched result, tiled according to `--retile_z_size`

Full details about the stitching pipeline [are available](https://github.com/saalfeldlab/stitching-spark).

### Segmentation

TBD

### Spots

* **tiles** - n5 formatted stack retiled for spot extraction

### Registration

If the acquisition was registered (i.e. for every round except the fixed round) this directory will contain a `<moving>-to-<fixed>` directory, e.g `LHA3_R5_medium-to-LHA3_R3_medium`. Inside that folder:

* **tiles** - tile-specific intermediate files 
* **aff** - result of RANSAC affine alignment
* **transform** - registration transform (n5 format)
* **invtransform** - inverse of registration transform (n5 format)
* **warped** - final registered imagery (n5 format)

### Intensities

TBD

### Spots

TBD
