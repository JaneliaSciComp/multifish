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

All containers used by the pipeline have been made available on Docker Hub. You can rebuild these to make customizations or to replace the algorithms used. To build the containers and push to a Docker registry:

#### Airlocalize container
```
cd containers/airlocalize
docker build -t registry.int.janelia.org/janeliascicomp/spotextraction:1.0  .
docker push registry.int.janelia.org/janeliascicomp/spotextraction:1.0
```

#### Spot assignment container
```
cd containers/assignment
docker build -t registry.int.janelia.org/janeliascicomp/spot_assignment:1.0 .
docker push registry.int.janelia.org/janeliascicomp/spot_assignment:1.0
```

#### Bigstream container
```
cd containers/bigstream
docker build --build-arg GIT_TAG=prototype -t registry.int.janelia.org/janeliascicomp/registration:1.0 .
docker push registry.int.janelia.org/janeliascicomp/registration:1.0
```

#### Segmentation container
```
cd containers/segmentation
docker build -t registry.int.janelia.org/janeliascicomp/segmentation:1.0 .
docker push registry.int.janelia.org/janeliascicomp/segmentation:1.0
```

#### Spot extraction container

TBD
