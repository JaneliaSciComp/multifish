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

All containers used by the pipeline have been made available on Docker Hub. You can rebuild these to make customizations or to replace the algorithms used. To build the containers and push to Docker Hub you can install [maru](https://github.com/JaneliaSciComp/maru) and run `maru build`, or invoke Docker manually:

#### Stitching container
Container used for Spark-based stitching.

    cd containers/stitching
    docker build -t multifish/stitching:latest .
    docker push multifish/stitching:latest

#### Spot extraction container
Container used for spot detection/extraction.

    cd containers/spot_extraction
    docker build -t multifish/spot_extraction:latest .
    docker push multifish/spot_extraction:latest

#### Segmentation container
Container used for cell segmentation.

    cd containers/segmentation
    docker build -t multifish/segmentation:latest .
    docker push multifish/segmentation:latest

#### Registration container
Container used for registration and spot warping.

    cd containers/registration
    docker build --build-arg GIT_TAG=prototype -t multifish/registration:latest .
    docker push multifish/registration:latest

#### Spot assignment container
Container used for intensity measurement and spot assignment.

    cd containers/spot_assignment
    docker build -t multifish/spot_assignment:latest .
    docker push multifish/spot_assignment:latest
