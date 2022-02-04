#!/bin/bash
set -e 

BASEDIR=$(cd "$(dirname "$0")"; pwd)
NEXTFLOW_SPARK_GITURL=https://github.com/JaneliaSciComp/nextflow-spark
NEXTFLOW_SPARK_VERSION=1.4.0

# Download Nextflow Spark module
mkdir -p ${BASEDIR}/external-modules/spark
curl -skL ${NEXTFLOW_SPARK_GITURL}/archive/${NEXTFLOW_SPARK_VERSION}.tar.gz \
    | tar -xz --strip-components=1 -C ${BASEDIR}/external-modules/spark

echo "Setup complete"
