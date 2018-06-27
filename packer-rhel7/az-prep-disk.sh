#!/bin/bash

filenameplusext=$(cat manifest.json | jq '.builds[] .files[0] .name' | tr -d '"' | tail -1)
filename=$(basename "$filenameplusext")
extension="${filename##*.}"
filename="${filename%.*}"

# full file path
fullpath=$(readlink -f "$filename/$filename.$extension")

# grab the full dir name, plus filename before the extension
fulldirpath=$(dirname "$fullpath")

echo  "Preparing VHD disk for $filename"

# convert to raw
qemu-img convert -f qcow2 -O raw "$fullpath" "$filename"/"$filename".raw

MB=$((1024*1024))
size=$(qemu-img info -f raw --output json "$filename"/"$filename".raw | \
  gawk 'match($0, /"virtual-size": ([0-9]+),/, val) {print val[1]}')

rounded_size=$((($size/$MB + 1)*$MB))
qemu-img resize -f raw "$filename"/"$filename".raw $rounded_size

# Convert the raw disk to a fixed-sized VHD (note need to use "force_size"):
qemu-img convert -f raw -O vpc -o subformat=fixed,force_size "$filename"/"$filename".raw "$filename"/"$filename".vhd
