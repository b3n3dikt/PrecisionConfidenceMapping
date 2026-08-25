#!/bin/bash

pngpath=${1}

# Read all png files matching the wildcard into an array
mapfile -t files < <(ls -1 ${pngpath})
# Read all png files into an array
#mapfile -t files < <(ls -1 *probability.png)
module load ffmpeg

# Base command
cmd="ffmpeg "

# Filter complex part start
filter_complex=""

# Generate the filter_complex part to horizontally stack images
# Since we have 15 images and want a 3x5 grid, we process 3 images at a time
for ((i=0; i<${#files[@]}; i+=3)); do
    # Add input files to command
    cmd+="-i ${files[i]} "
    [[ $(($i + 1)) -lt ${#files[@]} ]] && cmd+="-i ${files[i+1]} "
    [[ $(($i + 2)) -lt ${#files[@]} ]] && cmd+="-i ${files[i+2]} "

    # Create a row with 3 images
    filter_complex+="[${i}:v][$(($i+1)):v][$(($i+2)):v]hstack=inputs=3[row$(($i/3))]; "
done

# Now, stack the rows vertically
for ((i=0; i<${#files[@]}/3; i++)); do
    filter_complex+="[row$i]"
done

filter_complex+="vstack=inputs=$((${#files[@]}/3))[v]"

# Final command assembly
cmd+="-filter_complex \"$filter_complex\" -map \"[v]\" all_networks_probability_images.png"

# Execute the command
eval $cmd
