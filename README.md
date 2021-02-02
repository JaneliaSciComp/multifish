# Multifish Pipeline

![Pipeline Diagram](docs/pipeline_diagram.png)

## Prerequisites

You must have [Nextflow](https://www.nextflow.io) and [Singularity](https://sylabs.io) installed to run this pipeline. If you are running in an HPC cluster, [Singularity](https://sylabs.io) must be installed on all the cluster nodes.

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

More examples are available in the [examples](examples) directory.

## Development

If you are a software developer, please refer to the [Development docs](docs/Development.md).

