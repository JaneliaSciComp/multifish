#!/bin/bash
umask 0002

if [ -z "$SCRATCH_DIR" ] ; then
    echo "SCRATCH_DIR not set, creating one using default TMPDIR"
    export MCR_CACHE_ROOT=`mktemp -u -d`
else
    export MCR_CACHE_ROOT=`mktemp -u -d -p "${SCRATCH_DIR}/mcr_cache_$$"`
fi

function cleanTemp {
    if [ -n "$KEEP_MCR" ] ; then
        echo "Keep ${MCR_CACHE_ROOT}"
    else
        echo "Remove ${MCR_CACHE_ROOT}"
        rm -rf ${MCR_CACHE_ROOT} || true
        echo "Cleaned up temporary files at $MCR_CACHE_ROOT"
    fi
}
trap cleanTemp EXIT

echo "Creating MCR_CACHE_ROOT ${MCR_CACHE_ROOT}"
mkdir -p ${MCR_CACHE_ROOT}

echo "Running AirLocalize (MCR_CACHE_ROOT=${MCR_CACHE_ROOT})"
python /app/airlocalize/scripts/air_localize_mcr.py $*
