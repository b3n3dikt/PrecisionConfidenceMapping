#!/bin/bash

# Function to repeat a file path in an output file
repeat_path_in_file() {
  local number=$1
  local file_path=$2
  local out_path=$3

  # Ensure the output file is empty before writing
  > $out_path

  # Write the file path the specified number of times
  for ((i=1; i<=number; i++)); do
    echo "$file_path" >> $out_path
  done

  echo "Successfully wrote $file_path $number times to $out_path"
}

# Ensure correct number of arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <number> <file_path> <out_path>"
  exit 1
fi

# Call the function with arguments
repeat_path_in_file $1 $2 $3