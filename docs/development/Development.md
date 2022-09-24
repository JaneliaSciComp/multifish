---
layout: default
has_children: true
nav_order: 40
---

# Development

## Working with submodules

To pull in the submodules:

    git submodule init
    git submodule update

To update the external modules, you need to pull from Git with a special flag:

    git pull --recurse-submodules

To make changes to a submodule, cd into its directory and then checkout the master branch:

    cd external-modules/spark 
    git checkout master

Commit as normal, then back at the root update the submodule commit pointer and check it in:

    git submodule update --remote
    git commit external-modules/spark -m "Updated submodule to HEAD"

## Editing parameter schema

The `nextflow_schema.json` file contains the list of parameters and their documentation, and is used to automatically generate the Nextflow Tower UI for this pipeline. If you want to change the parameters or their docs, use the [nf-core schema builder](https://nf-co.re/pipeline_schema_builder). Copy and paste the contents of the [nextflow_schema.json](../nextflow_schema.json) file into the tool to begin editing, and copy it back when you are done. Don't forget to update the parameter docs, as described below.

## Generating parameter docs

To generate the Parameters documentation from the Nextflow schema:

    nf-core schema docs -o temp.md -f -c parameter,description,type

Then copy and paste the new documentation tables into the `docs/Parameters.md` file, and delete `temp.md`.

## Building containers

All containers used by the pipeline have been made available on Docker Hub and AWS ECR. You can rebuild these to make customizations or to replace the algorithms used. To build the containers and push to Docker Hub, install [maru](https://github.com/JaneliaSciComp/maru) and run `maru build`.

## Publishing containers

To push to Docker Hub, you need to login first:

    docker login

To push to AWS ECR, you need to login as follows:

    aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
