#!/bin/bash
umask 0002

if [ -z "$SCRATCH_DIR" ] ; then
    echo "SCRATCH_DIR not set, creating one using default TMPDIR"
    export MCR_CACHE_ROOT=`mktemp -d`
else
    export MCR_CACHE_ROOT="${SCRATCH_DIR}/mcr_cache_$$"
fi
    

function cleanTemp {
    rm -rf ${MCR_CACHE_ROOT}
    echo "Cleaned up temporary files at $MCR_CACHE_ROOT"
}
trap cleanTemp EXIT

echo "Creating MCR_CACHE_ROOT ${MCR_CACHE_ROOT}"
mkdir -p ${MCR_CACHE_ROOT}

echo "Running AirLocalize"
python /app/airlocalize/scripts/air_localize_mcr.py $*
