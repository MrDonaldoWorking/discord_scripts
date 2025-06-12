#!/bin/zsh

reduce_image() {
    local filepath="$1"
    local file=$(basename $filepath)
    local dir=$(dirname $filepath)
    local new_size=${2:-1200}  # Default size is 1200 if not provided

    local original_width=$(sips -g pixelWidth "$filepath" | awk "/pixelWidth/{print \$2}")
    local original_height=$(sips -g pixelHeight "$filepath" | awk "/pixelHeight/{print \$2}")

    if [ -z "$original_width" ] || [ -z "$original_height" ]; then
        echo "Skipping $filepath. Unable to get image dimensions."
        return
    fi

    # Calculate new dimensions while maintaining the original aspect ratio
    if ((original_width > original_height)); then
        new_height=$((new_size * original_height / original_width))
        new_width=$new_size
    else
        new_width=$((new_size * original_width / original_height))
        new_height=$new_size
    fi

    mkdir -p "$dir/reduced"

    # Resize the image
    sips -Z $new_size --out "$dir/reduced" "$dir/$file"
    echo "Resized $file to ${new_width}x${new_height}"
}

# Check if the Swift binary exists
if [[ ! -x ~/discord_scripts/createpdf.o ]]; then
    echo "Error: Swift binary not found at ~/discord_scripts/createpdf.o"
    echo "Compile first with: swiftc ~/discord_scripts/createPDF.swift -o ~/discord_scripts/createpdf.o"
    exit 1
fi

# Get root directory (default to current directory)
root_dir=${1:-PWD}
pdf_dir=${2:-PWD}

# Verify directory exists
if [[ ! -d "$root_dir" ]]; then
    echo "Error: Directory '$root_dir' does not exist"
    exit 1
fi

find "${root_dir}" -type d -name 'reduced' -print -delete

mkdir -p "${pdf_dir}"
current_datetime=$(date +%Y-%m-%dT%H:%M:%S)
mkdir -p "${pdf_dir}/${current_datetime}"

# Check for blacklist file
blacklist_file="${pdf_dir}/blacklist.txt"
declare -A folder_blacklist
declare -A partial_blacklist

if [[ -f "$blacklist_file" ]]; then
    echo "Found blacklist file: $blacklist_file"
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        
        if [[ "$line" == *:* ]]; then
            # Partial blacklist entry
            folder=${line%%:*}
            files=${line#*:}
            partial_blacklist[$folder]=${files## } # Trim leading space
        else
            # Full folder blacklist
            folder_blacklist[$line]=1
        fi
    done < "$blacklist_file"
else
    echo "Warning: No blacklist.txt found in $pdf_dir"
    echo "Continuing without blacklist filtering"
fi

# Process each child directory
for dir in "$root_dir"/*/; do
    # Remove trailing slash and get directory name
    dir=${dir%/}
    dir_name=${dir##*/}

    # Skip if not a directory
    [[ ! -d "$dir" ]] && continue

    # Check if folder is blacklisted
    if [[ -n "${folder_blacklist[$dir_name]}" ]]; then
        echo "Skipping blacklisted folder: $dir_name"
        continue
    fi

    # Get all supported image files in lexicographic order
    images=("$dir"/*.(jpg|jpeg|png|gif|tiff|tif|heic|webp|bmp)(N))
    images=(${(o)images})  # Sort lexicographically

    for image in "${images[@]}"; do
        reduce_image "$image"
    done

    reduced_images=("$dir"/reduced/*.(jpg|jpeg|png|gif|tiff|tif|heic|webp|bmp)(N))
    reduced_images=(${(o)reduced_images})  # Sort lexicographically

    # Apply partial blacklist if exists for this folder
    if [[ -n "${partial_blacklist[$dir_name]}" ]]; then
        echo "Applying partial blacklist for $dir_name"
        filtered_images=()
        blacklisted_files=(${=partial_blacklist[$dir_name]}) # Split by spaces

        for img in "${reduced_images[@]}"; do
            img_name=${img##*/}
            include=true
            for blacklisted in "${blacklisted_files[@]}"; do
                if [[ "$img_name" == "$blacklisted" ]]; then
                    include=false
                    break
                fi
            done
            $include && filtered_images+=("$img")
        done

        reduced_images=("${filtered_images[@]}")
        echo "Filtered out ${#blacklisted_files[@]} images, ${#reduced_images[@]} remaining"
    fi

    # Skip if no images found
    if [[ ${#reduced_images[@]} -eq 0 ]]; then
        echo "No images found in $dir_name, skipping..."
        continue
    fi

    # Create PDF filename based on directory name
    pdf_name="${dir_name}.pdf"
    pdf_path="${pdf_dir}/${current_datetime}/${pdf_name}"

    echo "Creating PDF for $dir_name with ${#reduced_images[@]} images..."

    # Prepare arguments for Swift binary (output first, then images)
    args=("$pdf_path")
    args+=(${reduced_images[@]})

    # Call the Swift binary
    (
        export CG_PDF_VERBOSE=1
        echo "=== ~/discord_scripts/createpdf.o ${args[@]}"
        ~/discord_scripts/createpdf.o ${args[@]}
    )

    # Check result
    if [[ $? -eq 0 ]] && [[ -f "$pdf_path" ]]; then
        echo "Successfully created: $pdf_path"
    else
        echo "Error creating PDF for $dir_name"
    fi
done

echo "PDF creation complete"
