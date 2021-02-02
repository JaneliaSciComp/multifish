# Multifish Pipeline

## Prerequisites

You must have [Nextflow](https://www.nextflow.io) installed to run this pipeline. Tasks can be executed using either [Singularity](https://sylabs.io) or [Docker](https://www.docker.com/). Most HPC clusters only support Singularity, while Docker is useful for running on non-Linux workstations and in the cloud.

## Getting Started

### Configure and build
```
./setup.sh
```

### Run the pipeline locally
```
./main.nf [arguments]
```

### Run the pipeline on IBM Platform LSF 
This also sets a project flag to show how to set LSF options.
```
./main.nf -profile lsf --lsf_opts "-P multifish" [arguments]
```

More examples are available in the `examples` directory.

## Development

If you are a software developer, please refer to the [Development docs](Development.md).

