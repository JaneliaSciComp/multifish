---
layout: default
parent: Nextflow Tower
nav_order: 10
---

# Running on AWS using Nextflow Tower

A public demonstration version of Tower is available at [tower.nf](https://tower.nf) and can be used to execute the pipeline on any cloud provider. You can log in here:

[Access the Public Nextflow Tower](https://tower.nf){: .btn .btn-blue }

The first time you log in, your account request will need to be approved manually by the Nextflow team. Once you get an email about your account being activated, you'll be able to log in again and run the pipeline.

## Creating a Compute Environment

You will first need to create a compute environment in Tower to describe your compute resources. Use the "Tower Forge" method to automatically create the required resources. The official documentation provides [detailed instructions](https://help.tower.nf/compute-envs/aws-batch/#forge-aws-resources) to set this up. Below are some hints for the values that we found works for this pipeline.

![Screen of creating an AWS compute environment](../images/compute_env_aws.png)

## Adding the pipeline

In the *Launchpad* tab, click **New pipeline** and fill in these values:

![Screenshot of creating a new pipeline](../images/new_pipeline.png)

## Launching the pipeline

When you click on the pipeline in the Launchpad, you will see all of the parameters laid out in a web GUI. Click "Upload params file" and select one of the JSON files in the examples directory, for example `demo_tiny.json`. This will populate the parameters with the values needed to run the pipeline to process the `demo_tiny` data set.

Fill in the `shared_work_dir` to point to a cluster-accessible directory, for example your HOME path. Now click the Launch button. This will begin by downloading data in the data_manifest, adn then running the complete analysis pipeline.
