#!/bin/bash
#
# Wait for all of the filepaths given as arguments. This script exits successfully once all the paths exist.
# If any file takes longer than MAX_WAIT_SECS to appear, the script fails.
#

SLEEP_SECS="${SLEEP_SECS:-1}"
MAX_WAIT_SECS="${MAX_WAIT_SECS:-30}"

filelist=$@
for f in ${filelist}; do

    echo "Checking for $f"
    SECONDS=0

    while ! test -e "$f"; do
        sleep $SLEEP_SECS
        if (( $SECONDS < $MAX_WAIT_SECS )); then
            echo "Waiting for $f"
            SECONDS=$(( $SECONDS + $SLEEP_SECS ))
        else
            echo "Timed out after $SECONDS seconds while waiting for $f"
            exit 1
        fi
    done
done
