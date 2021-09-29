---
layout: default
parent: Platforms
nav_order: 1
---

# Local

To run the pipeline locally, you can use simply the standard profile:

    ./main.nf [arguments]

This is equivalent to specifying the `localsingularity` profile:

    ./main.nf -profile localsingularity [arguments]

Alternatively, you can use Docker instead of Singularity to execute the processes by using the `localdocker` profile:

    ./main.nf -profile localdocker [arguments]
