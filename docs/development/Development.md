---
layout: default
has_children: true
nav_order: 40
---

# Development

## Working with submodules

To pull in the submodules:

    git submodule init
    git submodule update

To update the external modules, you need to pull from Git with a special flag:

    git pull --recurse-submodules

To make changes to a submodule, cd into its directory and then checkout the master branch:

    cd external-modules/spark 
    git checkout master

Commit as normal, then back at the root update the submodule commit pointer and check it in:

    git submodule update --remote
    git commit external-modules/spark -m "Updated submodule to HEAD"

## Building containers

All containers used by the pipeline have been made available on Docker Hub. You can rebuild these to make customizations or to replace the algorithms used. To build the containers and push to Docker Hub, install [maru](https://github.com/JaneliaSciComp/maru) and run `maru build`.
