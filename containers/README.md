# Docker Containers

This directory contains one subfolder for every Docker container used in the pipeline. Each container packages the entire system environment necessary for running that step of the pipeline, making the pipeline trivially portable across sytems.

To easily rebuild these containers, install Docker and [maru](https://github.com/JaneliaSciComp/maru) and run `maru build`. 

See the [Development docs](../docs/Development.md) for more information.
