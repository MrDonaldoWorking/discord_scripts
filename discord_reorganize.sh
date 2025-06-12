#!/usr/bin/env zsh

# Source directory (current directory by default)
source_dir="."

# Destination directory
dest_dir="./renamed_images"

# Create destination directory if it doesn't exist
mkdir -p "$dest_dir"

# Process all image files with the pattern number-number.ext
for file in "$source_dir"/*-*.{png,jpg,webp}(N); do
    # Get just the filename
    filename="${file##*/}"
    
    # Split the filename into parts
    base="${filename%.*}"
    ext="${filename##*.}"
    
    # Split the numbers
    num1="${base%-*}"
    num2="${base#*-}"
    
    # Create new filename
    new_filename="${num2}-${num1}.${ext}"
    
    # Copy file to destination with new name
    cp "$file" "$dest_dir/$new_filename"
    
    print "Copied: $filename → $new_filename"
done

print "✅ Done! All renamed images are in $dest_dir"