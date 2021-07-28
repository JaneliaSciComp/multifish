#!/bin/bash

manifest_path=$1
target_dir=$2
verify_md5="${3:-true}"

mkdir -p $target_dir

if [[ ! -e $manifest_path ]]; then
    url=$manifest_path
    manifest_path="$target_dir/manifest.txt"
    echo "Saving $manifest_path"
    curl -skL $url -o $manifest_path
fi

while read -r file md5 url ; do
    filepath=$target_dir/$file
    if [ ! -e $filepath ]; then
        echo "Saving $filepath"
        curl -skL $url -o $filepath
    fi
    if [ "$verify_md5" = true ]; then 
        if md5sum -s -c <<< "$md5  $filepath"; then
            echo "File checksum verified: $file"
        else
            echo "Checksum failed for $file"
            exit 1
        fi
    fi

    if [[ $file == *.zip ]]; then
        parentdir=$(dirname $filepath)
        unzip -o -d $parentdir $filepath
    fi

done < "$manifest_path"
