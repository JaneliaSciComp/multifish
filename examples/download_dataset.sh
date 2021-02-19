#!/bin/bash

files_txt_path=$1
input_dir_path=$2
verify_md5="${3:-true}"

mkdir -p $input_dir_path

while read -r file md5 url ; do
    filepath=$input_dir_path/$file
    if [ ! -e $filepath ]; then
        echo "Downloading: $file"
        curl -L $url -o $filepath
    fi
    if [ "$verify_md5" = true ]; then 
        if md5sum --status -c <<< "$md5 $filepath"; then
            echo "File checksum verified: $file"
        else
            echo "Checksum failed for $file"
            exit 1
        fi
    fi
done < "$files_txt_path"
