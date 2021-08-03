#!/bin/bash
umask 0002

if [ -z "$SCRATCH_DIR" ] ; then
    echo "SCRATCH_DIR not set, creating one using default TMPDIR"
    TEMP_DIR=`mktemp -d`
    export MCR_CACHE_ROOT="${TEMP_DIR}/mcr_cache_$$"
else
    TEMP_DIR="${SCRATCH_DIR}/mcr_cache_$$"
    export MCR_CACHE_ROOT="${TEMP_DIR}"
fi
    

function cleanTemp {
    rm -rf ${TEMP_DIR}
    echo "Cleaned up temporary files at $TEMP_DIR"
}
trap cleanTemp EXIT

echo "Creating MCR_CACHE_ROOT ${MCR_CACHE_ROOT}"
mkdir -p ${MCR_CACHE_ROOT}

echo "Running AirLocalize"
python /app/airlocalize/scripts/air_localize_mcr.py $*
