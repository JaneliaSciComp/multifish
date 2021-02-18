# Development

### Working with the submodules
To update the external modules, you need to pull from Git with a special flag:

    git pull --recurse-submodules

To make changes to a submodule, cd into its directory and then checkout the master branch:
    
    cd external-modules/spark 
    git checkout master

Commit as normal, then back at the root update the submodule commit pointer and check it in:

    git submodule update --remote
    git commit external-modules/spark -m "Updated submodule to HEAD"

### Building containers

All containers used by the pipeline have been made available on Docker Hub. You can rebuild these to make customizations or to replace the algorithms used. To build the containers and push to a Docker registry (the Janelia internal registry is used in the examples):

#### Registration container
Container used for registration and spot warping.

    cd containers/bigstream
    docker build --build-arg GIT_TAG=prototype -t registry.int.janelia.org/janeliascicomp/registration:latest .
    docker push registry.int.janelia.org/janeliascicomp/registration:latest

#### Segmentation container
Container used for cell segmentation.

    cd containers/segmentation
    docker build -t registry.int.janelia.org/janeliascicomp/segmentation:latest .
    docker push registry.int.janelia.org/janeliascicomp/segmentation:latest

#### Spot extraction container
Container used for spot detection/extraction.

    cd containers/airlocalize
    docker build -t registry.int.janelia.org/janeliascicomp/spotextraction:latest  .
    docker push registry.int.janelia.org/janeliascicomp/spotextraction:latest

#### Spot assignment container
Container used for intensity measurement and spot assignment.

    cd containers/assignment
    docker build -t registry.int.janelia.org/janeliascicomp/spot_assignment:latest .
    docker push registry.int.janelia.org/janeliascicomp/spot_assignment:latest
