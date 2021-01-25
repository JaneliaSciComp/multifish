## Multifish Pipeline


### Pull external modules

* First time
```
git submodule update --init --recursive
```

* Not first time
```
git pull --recurse-submodules
```

### Compile modules
```
mvn -f external-modules/stitching-spark/pom.xml package
```


### Building containers

All containers used by the pipeline have alredy been registered at the internal Janelia docker registry. 
This step is required only if the pipeline is run outside Janelia and there's no access to the internal docker registry.

#### Airlocalize container
```
docker build -t registry.int.janelia.org/janeliascicomp/spotextraction:1.0 airlocalize
```

#### Segmentation container
```
docker build -t registry.int.janelia.org/janeliascicomp/segmentation:1.0 segmentation
```
