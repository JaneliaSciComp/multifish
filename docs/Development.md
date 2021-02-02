# Development

### Updating submodules
To update the external modules, you need to pull from Git with a special flag:
```
git pull --recurse-submodules
```

### Building containers

All containers used by the pipeline have been made available at the internal Janelia docker registry.
This step is required only if the pipeline is run outside Janelia and there's no access to the internal docker registry.

#### Airlocalize container
```
docker build -t registry.int.janelia.org/janeliascicomp/spotextraction:1.0 airlocalize
```

#### Segmentation container
```
docker build -t registry.int.janelia.org/janeliascicomp/segmentation:1.0 segmentation
```

