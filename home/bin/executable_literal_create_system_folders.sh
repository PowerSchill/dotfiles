#!/bin/bash

SOURCE="/Users/ms185570/_Obsidian Vaults/NCR Vault/00-09 System/05 Templates/05.16 Category Templates"

cp -R "$SOURCE/AC*.*" ./
# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 replacement_string"
  exit 1
fi

replacement=$1

# Function to recursively rename directories containing "AC"
rename_directories() {
  # Find all directories with "AC" in their names and rename them
  find . -type d -name '*AC*' | grep 'AC' | sort -r | while IFS= read -r dir; do
    local newdir=$(echo "$dir" | sed "s/AC/${replacement}/g")
    if [[ "$dir" != "$newdir" ]]; then
      mv "$dir" "$newdir"
      echo "Renamed directory $dir to $newdir"
    fi
  done
}

# Function to recursively rename files containing "AC"
rename_files() {
  # Find all files with "AC" in their names and rename them
  find . -type f -name '*AC*' | grep 'AC' | while IFS= read -r file; do
    local newfile=$(echo "$file" | sed "s/AC/${replacement}/g")
    if [[ "$file" != "$newfile" ]]; then
      mv "$file" "$newfile"
      echo "Renamed file $file to $newfile"
    fi
  done
}

# Function to replace occurrences of "AC" within files
replace_inside_files() {
  # Find and replace the string "AC" inside files
  find . -type f | while IFS= read -r file; do
    if grep -q "AC" "$file"; then
      sed -i '' -e "s/AC/$replacement/g" "$file"
      echo "Replaced 'AC' with '$replacement' in $file"
    fi
  done
}

# Perform the renaming and replacing process
rename_directories
rename_files
replace_inside_files
