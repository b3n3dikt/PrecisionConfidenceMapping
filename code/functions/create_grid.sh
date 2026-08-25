#!/bin/bash

module load ffmpeg
rm -rf all_networks_probability_images.png
# Read all png files into an array
mapfile -t files < <(ls -1 *probability.png)

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
#!/bin/bash

# # Load ffmpeg module
# module load ffmpeg

# # Initialize an empty array to store file paths
# files=("$@")

# # Base ffmpeg command
# cmd="ffmpeg "

# # Initialize filter_complex part for ffmpeg
# filter_complex=""

# # Generate the filter_complex part to horizontally stack images
# for ((i=0; i<${#files[@]}; i+=3)); do
#     # Dynamically add input files to the command
#     cmd+="-i '${files[i]}' "
#     [[ $(($i + 1)) -lt ${#files[@]} ]] && cmd+="-i '${files[i+1]}' "
#     [[ $(($i + 2)) -lt ${#files[@]} ]] && cmd+="-i '${files[i+2]}' "
    
#     # Build the filter_complex string for horizontal stacking
#     # Ensure each input stream is correctly labeled ([0:v], [1:v], etc.)
#     filter_complex+="[${i}:v]"
#     [[ $(($i + 1)) -lt ${#files[@]} ]] && filter_complex+="[${i+1}:v]"
#     [[ $(($i + 2)) -lt ${#files[@]} ]] && filter_complex+="[${i+2}:v]"
#     filter_complex+="hstack=inputs=$((i+3<=${#files[@]}?3:${#files[@]}-i))[row${i}]; "
# done

# # Stack the rows vertically
# for ((i=0; i<${#files[@]}; i+=3)); do
#     filter_complex+="[row${i}]"
#     # Only add to the filter_complex if it's not the first row
#     if [[ $i -gt 0 ]]; then
#         prev=$((i-3))
#         filter_complex="[v${prev}][row${i}]vstack=inputs=2[v${i}]; "
#     fi
# done

# # Ensure the last vstack output is correctly mapped
# last_row=$(((${#files[@]}+2)/3-1))
# last_vstack=$((last_row*3))
# filter_complex+="[v${last_vstack}]"

# # Final command assembly
# cmd+="-filter_complex \"$filter_complex\" -map \"[v]\" all_networks_probability_images.png"

# # Execute the command
# eval $cmd

# #!/bin/bash

# # Load ffmpeg module
# module load ffmpeg

# # Initialize an empty array to store file paths
# #files=("$@")
# mapfile -t files < <(ls -1 *probability.png)

# # Base ffmpeg command
# cmd="ffmpeg "

# # Initialize filter_complex part for ffmpeg
# filter_complex=""

# # Generate the filter_complex part to horizontally stack images
# # Adjusts dynamically to the number of input images
# rowCount=${#files[@]}/3  # This script assumes that the total number of files is a multiple of 3
# for ((row=0; row<rowCount; row++)); do
#     for ((col=0; col<3; col++)); do
#         index=$((row * 3 + col))
#         cmd+="-i '${files[index]}' "
#         filter_complex+="[${index}:v]"
#         if ((col < 2)); then
#             filter_complex+=","
#         fi
#     done
#     filter_complex+="hstack=inputs=3[row${row}]; "
# done

# # Stack the rows vertically
# for ((i=0; i<rowCount; i++)); do
#     if ((i > 0)); then
#         filter_complex+="[v${i-1}][row${i}]"
#     else
#         filter_complex+="[row${i}]"
#     fi
#     filter_complex+="vstack=inputs=2"
#     if ((i < rowCount-1)); then
#         filter_complex+="[v${i}]; "
#     fi
# done

# # Final command assembly
# cmd+="-filter_complex \"$filter_complex\" -map \"[v]\" all_networks_probability_images.png"

# # Execute the command
# eval $cmd



# #!/bin/bash

# # Load ffmpeg module
# module load ffmpeg

# # Initialize an empty array to store file paths
# files=("$@")

# # Base ffmpeg command
# cmd="ffmpeg "

# # Initialize filter_complex part for ffmpeg
# filter_complex=""

# # Generate the filter_complex part to horizontally stack images
# # Adjusts dynamically to the number of input images
# for ((i=0; i<${#files[@]}; i+=3)); do
#     # Add input files to command
#     cmd+="-i '${files[i]}' "
#     [[ $(($i + 1)) -lt ${#files[@]} ]] && cmd+="-i '${files[i+1]}' "
#     [[ $(($i + 2)) -lt ${#files[@]} ]] && cmd+="-i '${files[i+2]}' "

#     # Create a row with up to 3 images
#     numInputs=$((i+3 <= ${#files[@]} ? 3 : ${#files[@]} - i))
#     filter_complex+="[${i}:v]"
#     [[ $(($i + 1)) -lt ${#files[@]} ]] && filter_complex+="[${i+1}:v]"
#     [[ $(($i + 2)) -lt ${#files[@]} ]] && filter_complex+="[${i+2}:v]"
#     filter_complex+="hstack=inputs=${numInputs}[row$(($i/3))]; "
# done

# # Stack the rows vertically
# rowCount=$(( (${#files[@]} + 2) / 3 )) # Calculate how many rows there are
# for ((i=0; i<rowCount; i++)); do
#     filter_complex+="[row$i]"
# done

# filter_complex+="vstack=inputs=${rowCount}[v]"

# # Final command assembly
# cmd+="-filter_complex \"$filter_complex\" -map \"[v]\" all_networks_probability_images.png"

# # Execute the command
# eval $cmd


# #!/bin/bash

# pngpath=${1}

# # Read all png files matching the wildcard into an array
# mapfile -t files < <(ls -1 ${pngpath})
# # Read all png files into an array
# #mapfile -t files < <(ls -1 *probability.png)
# module load ffmpeg

# # Base command
# cmd="ffmpeg "

# # Filter complex part start
# filter_complex=""

# # Generate the filter_complex part to horizontally stack images
# # Since we have 15 images and want a 3x5 grid, we process 3 images at a time
# for ((i=0; i<${#files[@]}; i+=3)); do
#     # Add input files to command
#     cmd+="-i ${files[i]} "
#     [[ $(($i + 1)) -lt ${#files[@]} ]] && cmd+="-i ${files[i+1]} "
#     [[ $(($i + 2)) -lt ${#files[@]} ]] && cmd+="-i ${files[i+2]} "

#     # Create a row with 3 images
#     filter_complex+="[${i}:v][$(($i+1)):v][$(($i+2)):v]hstack=inputs=3[row$(($i/3))]; "
# done

# # Now, stack the rows vertically
# for ((i=0; i<${#files[@]}/3; i++)); do
#     filter_complex+="[row$i]"
# done

# filter_complex+="vstack=inputs=$((${#files[@]}/3))[v]"

# # Final command assembly
# cmd+="-filter_complex \"$filter_complex\" -map \"[v]\" all_networks_probability_images.png"

# # Execute the command
# eval $cmd
