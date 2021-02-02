#!/bin/bash

# Pull external modules
git submodule update --init --recursive

# Compile modules
mvn -f external-modules/stitching-spark/pom.xml package

