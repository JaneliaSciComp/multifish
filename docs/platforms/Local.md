---
layout: default
parent: Platforms
name: Local Workstation
nav_order: 1
---

# Local Workstation

The pipeline runs on any Linux-based system using Singularity. Before running the pipeline, [follow the quick start instructions](../QuickStart.html) to make sure you have all of the prerequisites installed.

To run the pipeline locally you can use the default **standard** profile:

    ./main.nf [arguments]

This is equivalent to specifying the **localsingularity** profile:

    ./main.nf -profile localsingularity [arguments]

Alternatively, you can use Docker instead of Singularity to execute the processes by using the **localdocker** profile:

    ./main.nf -profile localdocker [arguments]
