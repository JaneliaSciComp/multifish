#!/bin/bash

if [ -d /scratch ] ; then
    export MCR_CACHE_ROOT="/scratch/${USER}/mcr_cache_$$"
else
    export MCR_CACHE_ROOT=`mktemp -u`
fi

umask 0002

[ -d ${MCR_CACHE_ROOT} ] || mkdir -p ${MCR_CACHE_ROOT}
echo "Use MCR_CACHE_ROOT ${MCR_CACHE_ROOT}"

python /app/airlocalize/scripts/air_localize_mcr.py $*

rm -rf ${MCR_CACHE_ROOT}
