#!/bin/bash

#SBATCH -J makesummary
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=10gb
#SBATCH -t 2:00:00
#SBATCH -p msismall
#SBATCH -A bart

shopt -s nullglob  # Ensures patterns with no matches disappear instead of staying literal

show_help() {
    echo "Usage: $0 [subject] [session] [TASK] [wildcard_folder_pattern] [base_dir] [analysisfolder] [out_base] [outname]"
    echo ""
    echo "Arguments (all optional, defaults in parentheses):"
    echo "  subject                 (default: sub-PFM3T7T01)"
    echo "  session                 (default: ses-combined)"
    echo "  TASK                    (default: restMENORDICtrimmed-70minutes-5minutes)"
    echo "  wildcard_folder_pattern (default: ExpData-5m_Perm-*)"
    echo "  base_dir                (default: /home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm)"
    echo "  analysisfolder          (default: bagged_reliability_curves_percent_split-100_variability_minute-5)"
    echo "  out_base                (default: ~/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/\${analysisfolder}/figs/individual_network_runs/\${subject}/)"
    echo "  outname                 (default: 5min_StandardTM_variability_output)"
    echo ""
    echo "Description:"
    echo "This script finds dscalar files, converts them to PNGs using quick_network_pic.sh, and generates an HTML summary."
    echo "If copypngs=1, it also copies PNGs to out_base with a unique filename that includes the wildcard pattern."
    echo ""
    echo "Options:"
    echo "  -h, --help   Show this help message and exit."
    exit 0
}


if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

subject=${1:-"sub-PFM3T7T01"}    
session=${2:-"ses-combined"}     
TASK=${3:-"restMENORDICtrimmed-70minutes-5minutes"}
wildcard_folder_pattern=${4:-"ExpData-5m_Perm-*"}  
base_dir=${5:-"/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm"}
analysisfolder=${6:-"bagged_reliability_curves_percent_split-100_variability_minute-5"}
out_base=${7:-"$HOME/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/${analysisfolder}/figs/individual_network_runs/${subject}/"}
outname=${8:-"5min_StandardTM_variability_output"}

copypngs=1
mkdir -p "${out_base}"
echo "Running $subject $session $wildcard_folder_pattern "

# Construct search paths (unquoted so glob can expand)
search_paths=(${base_dir}/${analysisfolder}/${subject}/${session}/${wildcard_folder_pattern}/${subject}/${session}/${TASK}/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network/)

echo "Search paths: ${search_paths[@]}"

# Convert dscalar.nii files to PNGs
find "${search_paths[@]}" -name "*recolored.dscalar.nii" -type f -exec /projects/standard/faird/shared/code/internal/utilities/figure_maker/quick_network_pic.sh {} \;

output_html="${out_base}/${subject}_${session}_${outname}.html"

echo "<html>" > "$output_html"
echo "<body>" >> "$output_html"

pattern_clean=$(echo "$wildcard_folder_pattern" | tr '*' 'X')

for search_dir in "${search_paths[@]}"; do
    if [[ -d "$search_dir" ]]; then
        for png_file in "$search_dir"/*_recolored.png; do
            if [[ -f "$png_file" ]]; then
                IFS='/' read -ra path_parts <<< "$png_file"
                wildcard_folder_name=""
                for part in "${path_parts[@]}"; do
                    if [[ $part == ExpData-* ]] || [[ $part == RefData-* ]]; then
                        wildcard_folder_name="$part"
                    fi
                done

                if [[ -z $wildcard_folder_name ]]; then
                    echo "Warning: Could not extract wildcard folder from $png_file"
                    continue
                fi

                echo "<h2>$subject $session $wildcard_folder_name</h2>" >> "$output_html"
                image_base=$(basename "$png_file")
                new_image_file="${subject}_${session}_${pattern_clean}_${wildcard_folder_name}_${image_base}"

                if [[ $copypngs -eq 1 ]]; then
                    cp "$png_file" "${out_base}/${new_image_file}"
                    echo "<img src=\"${new_image_file}\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
                else
                    echo "<img src=\"${png_file}\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
                fi
            fi
        done
    else
        echo "Directory not found: $search_dir"
    fi
done

echo "</body>" >> "$output_html"
echo "</html>" >> "$output_html"

echo "HTML file generated: $output_html"
ls -l "$output_html"

# #!/bin/bash

# #SBATCH -J makesummary
# #SBATCH --nodes=1
# #SBATCH --ntasks-per-node=1
# #SBATCH --cpus-per-task=1
# #SBATCH --mem=10gb
# #SBATCH -t 2:00:00
# #SBATCH -p msismall
# #SBATCH -A bart

# show_help() {
#     echo "Usage: $0 [subject] [session] [TASK] [wildcard_folder_pattern] [base_dir] [analysisfolder] [out_base] [outname]"
#     echo ""
#     echo "Arguments (all optional, defaults in parentheses):"
#     echo "  subject                 (default: sub-PFM3T7T01)"
#     echo "  session                 (default: ses-combined)"
#     echo "  TASK                    (default: restMENORDICtrimmed-70minutes-5minutes)"
#     echo "  wildcard_folder_pattern (default: ExpData-5m_Perm-*)"
#     echo "  base_dir                (default: /home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm)"
#     echo "  analysisfolder          (default: bagged_reliability_curves_percent_split-100_variability_minute-5)"
#     echo "  out_base                (default: ~/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/\${analysisfolder}/figs/individual_network_runs/\${subject}/)"
#     echo "  outname                 (default: 5min_StandardTM_variability_output)"
#     echo ""
#     echo "Description:"
#     echo "This script finds dscalar files, converts them to PNGs using quick_network_pic.sh, and generates an HTML summary."
#     echo "If copypngs=1, it also copies PNGs to out_base with a unique filename that includes the wildcard pattern."
#     echo ""
#     echo "Options:"
#     echo "  -h, --help   Show this help message and exit."
#     exit 0
# }

# # Check if the user asked for help
# if [[ "$1" == "-h" || "$1" == "--help" ]]; then
#     show_help
# fi

# # Get user inputs with defaults
# subject=${1:-"sub-PFM3T7T01"}    
# session=${2:-"ses-combined"}     
# TASK=${3:-"restMENORDICtrimmed-70minutes-5minutes"}
# wildcard_folder_pattern=${4:-"ExpData-5m_Perm-*"}  
# base_dir=${5:-"/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm"}
# analysisfolder=${6:-"bagged_reliability_curves_percent_split-100_variability_minute-5"}
# out_base=${7:-"~/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/${analysisfolder}/figs/individual_network_runs/${subject}/"}
# outname=${8:-"5min_StandardTM_variability_output"}

# copypngs=1
# mkdir -p "${out_base}"
# echo "Running $subject $session $wildcard_folder_pattern "

# # Construct search paths
# #search_paths="/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bagged_reliability_curves_percent_split-100_variability_minute-5/sub-PFM3T7T02/ses-combined/ExpData-5m_Perm-1/sub-PFM3T7T02/ses-combined/restMENORDICtrimmed-70minutes-5minutes/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network/"
# search_paths=(${base_dir}/${analysisfolder}/${subject}/${session}/${wildcard_folder_pattern}/${subject}/${session}/${TASK}/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network/)

# #search_paths=("$base_dir/${analysisfolder}/${subject}/${session}/${wildcard_folder_pattern}*/${subject}/${session}/${TASK}/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network/")

# echo ${search_paths}
# # Convert dscalar.nii files to PNGs using quick_network_pic.sh
# find "${search_paths[@]}" -name "*recolored.dscalar.nii" -type f -exec /projects/standard/faird/shared/code/internal/utilities/figure_maker/quick_network_pic.sh {} \;

# # Output HTML file
# output_html="${out_base}/${subject}_${session}_${outname}.html"

# # Start the HTML file
# echo "<html>" > "$output_html"
# echo "<body>" >> "$output_html"

# # Sanitize the wildcard pattern for filenames (replace '*' with 'X')
# pattern_clean=$(echo "$wildcard_folder_pattern" | tr '*' 'X')

# # Loop over the constructed search paths
# for search_dir in "${search_paths[@]}"; do
#     # Check if the directory exists
#     if [[ -d "$search_dir" ]]; then
#         # Find PNG files ending with '_recolored.png'
#         for png_file in "$search_dir"/*_recolored.png; do
#             if [[ -f "$png_file" ]]; then
#                 # Extract fields from the path
#                 IFS='/' read -ra path_parts <<< "$png_file"

#                 # Initialize variables
#                 wildcard_folder_name=""

#                 # Iterate over the path parts to find the wildcard folder
#                 for part in "${path_parts[@]}"; do
#                     if [[ $part == ExpData-* ]] || [[ $part == RefData-* ]]; then
#                         wildcard_folder_name="$part"
#                     fi
#                 done

#                 # Check if wildcard_folder_name was found
#                 if [[ -z $wildcard_folder_name ]]; then
#                     echo "Warning: Could not extract wildcard folder from $png_file"
#                     continue
#                 fi

#                 # Add a header to the HTML
#                 echo "<h2>$subject $session $wildcard_folder_name</h2>" >> "$output_html"

#                 # Get the base name of the image file
#                 image_base=$(basename "$png_file")
                
#                 # Create a new image filename to prevent collisions
#                 new_image_file="${subject}_${session}_${pattern_clean}_${wildcard_folder_name}_${image_base}"

#                 # If copypngs=1, copy the PNG to the out_base directory with the unique name
#                 if [[ $copypngs -eq 1 ]]; then
#                     cp "$png_file" "${out_base}/${new_image_file}"
#                     echo "<img src=\"${new_image_file}\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
#                 else
#                     # If not copying, reference the original location or skip
#                     # Here, we assume we always want to copy. Otherwise:
#                     # echo "<img src=\"${png_file}\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
#                     echo "<img src=\"${new_image_file}\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
#                 fi
#             fi
#         done
#     else
#         echo "Directory not found: $search_dir"
#     fi
# done

# # Close the HTML file
# echo "</body>" >> "$output_html"
# echo "</html>" >> "$output_html"

# echo "HTML file generated: $output_html"



# #!/bin/bash

# #SBATCH -J makesummary
# #SBATCH --nodes=1
# #SBATCH --ntasks-per-node=1
# #SBATCH --cpus-per-task=1
# #SBATCH --mem=10gb
# #SBATCH -t 2:00:00
# #SBATCH -p msismall
# #SBATCH -A bart

# # Get user inputs
# subject=${1:-"sub-PFM3T7T01"}    # Default value if not provided
# session=${2:-"ses-combined"}     # Default value if not provided
# TASK=${3:-"restMENORDICtrimmed-70minutes-5minutes"}
# wildcard_folder_pattern=${4:-"ExpData-5m_Perm-*"}  # Supports wildcards
# base_dir=${5:-"/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm"}
# analysisfolder=${6:-"bagged_reliability_curves_percent_split-100_variability_minute-5"}
# out_base=${7:-"~/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/${analysisfolder}/figs/individual_network_runs/${subject}/"}
# outname=${8:-"5min_StandardTM_variability_output"}

# copypngs=1
# mkdir -p ${out_base}
# echo "Running $subject $session $wildcard_folder_pattern "
# search_paths=("$base_dir"/${analysisfolder}/"$subject"/"$session"/$wildcard_folder_pattern/"$subject"/"$session"/${TASK}/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network/)

# find ${search_paths} -name "*recolored.dscalar.nii" -type f -exec /projects/standard/faird/shared/code/internal/utilities/figure_maker/quick_network_pic.sh {} \;



# # Output HTML file
# output_html="${out_base}/${subject}_${session}_${outname}.html"

# # Create images directory in the current working directory
# mkdir -p images

# # Start the HTML file
# echo "<html>" > "$output_html"
# echo "<body>" >> "$output_html"


# # Loop over the constructed search paths
# for search_dir in "${search_paths[@]}"; do
#     # Check if the directory exists
#     if [[ -d "$search_dir" ]]; then
#         # Use shell globbing to find PNG files ending with '_recolored.png'
#         for png_file in "$search_dir"/*_recolored.png; do
#             if [[ -f "$png_file" ]]; then
#                 # Extract fields from the path
#                 IFS='/' read -ra path_parts <<< "$png_file"

#                 # Initialize variables
#                 wildcard_folder_name=""

#                 # Iterate over the path parts to find the wildcard folder
#                 for part in "${path_parts[@]}"; do
#                     if [[ $part == ExpData-* ]] || [[ $part == RefData-* ]]; then
#                         wildcard_folder_name="$part"
#                     fi
#                 done

#                 # Check if wildcard_folder_name was found
#                 if [[ -z $wildcard_folder_name ]]; then
#                     echo "Warning: Could not extract wildcard folder from $png_file"
#                     continue
#                 fi

#                 # Add a header to the HTML
#                 echo "<h2>$subject $session $wildcard_folder_name</h2>" >> "$output_html"

#                 # Get the base name of the image file
#                 image_base=$(basename "$png_file")
#                 # Create a new image filename to prevent collisions
#                 new_image_file="${subject}_${session}_${wildcard_folder_name}_${image_base}"

#                 # Copy the image to the images directory with the new name
#                 cp "$png_file" "images/$new_image_file"

#                 # Add the image to the HTML
#                 echo "<img src=\"images/$new_image_file\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
#             fi
#         done
#     else
#         echo "Directory not found: $search_dir"
#     fi
# done

# # Close the HTML file
# echo "</body>" >> "$output_html"
# echo "</html>" >> "$output_html"

# echo "HTML file generated: $output_html"





# find /home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bagged_reliability_curves_percent_split-100_variability_minute-5/${subject}/${session}/ExpData-5m_Perm-*/${subject}/${session}/${TASK}/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network/ -name "*recolored.dscalar.nii" -type f -exec /projects/standard/faird/shared/code/internal/utilities/figure_maker/quick_network_pic.sh {} \;





# # Output HTML file
# output_html="${subject}_${session}_${outname}.html"

# # Create images directory in the current working directory
# mkdir -p images

# # Start the HTML file
# echo "<html>" > "$output_html"
# echo "<body>" >> "$output_html"

# # Base directory to search for PNG files
# base_dir="/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs"

# # Construct the specific path using user inputs
# search_paths=("$base_dir"/3T/2mm/bagged_reliability_curves_percent_split-100_variability_minute-5/"$subject"/"$session"/$wildcard_folder_pattern/"$subject"/"$session"/restMENORDICtrimmed-70minutes-5minutes/standard/Standard_Template_Matching/abcd-SCAN_template/SCAN_network)

# # Loop over the constructed search paths
# for search_dir in "${search_paths[@]}"; do
#     # Check if the directory exists
#     if [[ -d "$search_dir" ]]; then
#         # Use shell globbing to find PNG files ending with '_recolored.png'
#         for png_file in "$search_dir"/*_recolored.png; do
#             if [[ -f "$png_file" ]]; then
#                 # Extract fields from the path
#                 IFS='/' read -ra path_parts <<< "$png_file"

#                 # Initialize variables
#                 wildcard_folder_name=""

#                 # Iterate over the path parts to find the wildcard folder
#                 for part in "${path_parts[@]}"; do
#                     if [[ $part == ExpData-* ]] || [[ $part == RefData-* ]]; then
#                         wildcard_folder_name="$part"
#                     fi
#                 done

#                 # Check if wildcard_folder_name was found
#                 if [[ -z $wildcard_folder_name ]]; then
#                     echo "Warning: Could not extract wildcard folder from $png_file"
#                     continue
#                 fi

#                 # Add a header to the HTML
#                 echo "<h2>$subject $session $wildcard_folder_name</h2>" >> "$output_html"

#                 # Get the base name of the image file
#                 image_base=$(basename "$png_file")
#                 # Create a new image filename to prevent collisions
#                 new_image_file="${subject}_${session}_${wildcard_folder_name}_${image_base}"

#                 # Copy the image to the images directory with the new name
#                 cp "$png_file" "images/$new_image_file"

#                 # Add the image to the HTML
#                 echo "<img src=\"images/$new_image_file\" alt=\"Image\" style=\"max-width:100%;height:auto;\">" >> "$output_html"
#             fi
#         done
#     else
#         echo "Directory not found: $search_dir"
#     fi
# done

# # Close the HTML file
# echo "</body>" >> "$output_html"
# echo "</html>" >> "$output_html"

# echo "HTML file generated: $output_html"
