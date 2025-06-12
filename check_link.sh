#!/bin/zsh

# Function to check if filename matches the pattern
is_valid_filename() {
    local url="$1"
    local filename=$(basename "$url")
    filename="${filename%%\?*}"  # Remove query parameters
    
    # Check if filename matches the pattern
    [[ "$filename" =~ ^([[:alnum:]]+_)?[0-9]+-[0-9]+\.(png|jpg|webp)$ ]]
}

if ! is_valid_filename "$1"; then
    echo "It is not valid link"
else
    echo "VALID!"
fi
