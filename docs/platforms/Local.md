---
layout: default
parent: Platforms
nav_order: 1
---

# Local

The pipeline should run on any Linux-based system using Singularity. You should also be able to run it on Mac/Windows systems using Docker, but this has not been fully tested.

To run the pipeline locally you can use the default **standard** profile:

    ./main.nf [arguments]

This is equivalent to specifying the **localsingularity** profile:

    ./main.nf -profile localsingularity [arguments]

Alternatively, you can use Docker instead of Singularity to execute the processes by using the **localdocker** profile:

    ./main.nf -profile localdocker [arguments]
