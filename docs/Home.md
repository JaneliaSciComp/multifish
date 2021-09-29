---
layout: page
permalink: /
nav_order: 1
---

# Overview

## EASI-FISH Pipeline

The purpose of this pipeline is to analyze imagery for spatial transcriptomics collected using [EASI-FISH](https://github.com/multiFISH/EASI-FISH) (Expansion-Assisted Iterative Fluorescence *In Situ* Hybridization). It includes automated image stitching, distributed multi-round image registration, cell segmentation, and distributed spot detection.

![Pipeline Diagram](images/pipeline_diagram.png)

## Modules

This pipeline is containerized and portable across the various platforms supported by [Nextflow](https://www.nextflow.io). So far it has been tested on a standalone workstation, the Janelia compute cluster (IBM Platform LSF), and AWS. If you run it successfully on any other platform, please let us know so that we can update this documentation.

The pipeline includes the following modules:

* **stitching** - Spark-based distributed stitching pipeline
* **spot_extraction** - Spot detection using Airlocalize
* **segmentation** - Cell segmentation using Starfinity
* **registration** - Bigstream distributed registration pipeline
* **warp_spots** - Warp detected spots to registration
* **measure_intensities** - Intensity measurement
* **assign_spots** - Mapping of spot counts to segmented cells
