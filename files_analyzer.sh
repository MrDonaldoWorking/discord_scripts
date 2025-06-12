#!/bin/zsh

# Check if root directory argument is provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <root_directory>"
    exit 1
fi

root_dir=$1

# Verify directory exists
if [[ ! -d "$root_dir" ]]; then
    echo "Error: Directory '$root_dir' does not exist"
    exit 1
fi

# Get all files in root directory (excluding directories)
root_files=($root_dir/*(.))
total_root_files=${#root_files[@]}

# Initialize arrays and counters
child_dirs=($root_dir/*(/))
total_child_files=0
declare -A files_in_children

echo "Analyzing directory structure of: $root_dir"
echo "-------------------------------------------"

# Process each child directory
for dir in $child_dirs; do
    # Get files in child directory
    child_files=($dir/*(.))
    count=${#child_files[@]}
    total_child_files=$((total_child_files + count))
    
    # Record each file found in child directories
    for file in $child_files; do
        filename=${file##*/}
        files_in_children[$filename]=1
    done
done

# Find files in root not present in any child directory
missing_files=()
for file in $root_files; do
    filename=${file##*/}
    if [[ -z ${files_in_children[$filename]} ]]; then
        missing_files+=($filename)
    fi
done

# Output results
echo "Total files in root directory: $total_root_files"
echo "Total files in all child directories: $total_child_files"
echo ""
echo "Files in root directory missing from all child directories:"
if [[ ${#missing_files[@]} -eq 0 ]]; then
    echo "  (all files exist in child directories)"
else
    for file in $missing_files; do
        echo "  $file"
    done
fi

# Calculate and show statistics
if [[ $total_root_files -gt 0 ]]; then
    coverage=$((100 * (total_root_files - ${#missing_files[@]}) / total_root_files))
    echo ""
    echo "Coverage: $coverage% of root files exist in child directories"
fi
