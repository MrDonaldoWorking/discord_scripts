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
    sips -Z $new_size --out "$dir/reduced" "$dir/$file" > /dev/null 2>&1
    # echo "Resized $file to ${new_width}x${new_height}"
}

get_file_size() {
    local file="$1"
    echo $(ls -l "$file" | cut -d ' ' -f 8)
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

find "${root_dir}" -type d -name 'reduced' -print -exec rm -r {} \;

mkdir -p "${pdf_dir}"
current_datetime=$(date +%Y-%m-%dT%H:%M:%S)
mkdir -p "${pdf_dir}/${current_datetime}"

# Check for blacklist file
blacklist_file="${pdf_dir}/blacklist.txt"
declare -A folder_blacklist
declare -A partial_blacklist
declare -A redirect_map

if [[ -f "$blacklist_file" ]]; then
    echo "Found blacklist file: $blacklist_file"
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == *" -> "*:* ]]; then
            # Redirect entry: <Folder1> -> <Folder2>: <Image1> <Image2> ...
            source_folder=${line%%" -> "*}
            rest=${line#*" -> "}
            target_folder=${rest%%:*}
            files=${rest#*:}

            # Store the redirect mapping
            key="${source_folder}:${target_folder}"
            redirect_map[$key]="${files## }" # Trim leading space
        elif [[ "$line" == *:* ]]; then
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

# Redirect all possible files
for key in "${(@k)redirect_map}"; do
    source_folder=${key%%:*}
    target_folder=${key#*:}

    source_dir="${root_dir}/${source_folder}"
    target_dir="${root_dir}/${target_folder}"
    if [[ -d "$source_dir" ]]; then
        echo "Creating ${root_dir}/${target_folder} if it not exists"
        mkdir -p "${root_dir}/${target_folder}"

        files_to_redirect=(${=redirect_map[$key]})
        for file_to_redirect in "${files_to_redirect[@]}"; do
            source_file="${source_dir}/${file_to_redirect}"
            if [[ -f "$source_file" ]]; then
                echo "Apply redirect $source_folder -> $target_folder: $file_to_redirect"
                mv "${source_dir}/${file_to_redirect}" "${target_dir}"
            else
                echo "There is no $file_to_redirect in $source_dir"
            fi
        done
    else
        echo "There is no $source_folder directory! Redirect rule is ignored"
    fi
done

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
        # echo "=== ~/discord_scripts/createpdf.o ${args[@]}"
        ~/discord_scripts/createpdf.o ${args[@]}
    ) > /dev/null 2>&1

    # Check result
    if [[ $? -eq 0 ]] && [[ -f "$pdf_path" ]]; then
        echo "Successfully created: $pdf_path"
    else
        echo "Error creating PDF for $dir_name"
    fi
done

# Compare with previous result if exists
previous_results=(${(O)${(f)"$(find "${pdf_dir}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z -r | tr '\0' '\n')"}})
if (( ${#previous_results[@]} > 1 )); then  # Current + at least one previous
    # Sort by creation time (newest first) and get the second one (previous)
    previous_dir=(${previous_results[2]})
    current_dir="${pdf_dir}/${current_datetime}"

    echo "\nComparing with previous results in: ${previous_dir##*/}"

    # Find all PDFs in current directory
    for pdf in "${current_dir}"/*.pdf(N); do
        pdf_name="${pdf##*/}"
        previous_pdf="${previous_dir}/${pdf_name}"

        if [[ -f "$previous_pdf" ]]; then
            current_pdf_size=$(get_file_size "$pdf")
            previous_pdf_size=$(get_file_size "$previous_pdf")
            if [[ "$current_pdf_size" == "$previous_pdf_size" ]]; then
                echo "  Removing duplicate: $pdf_name (identical to previous)"
                rm "$pdf"
            else
                echo "  Keeping modified: $pdf_name (differs from previous)"
            fi
        fi
    done

    # Check if current directory is empty after comparison
    if [[ -z "$(ls -A "${current_dir}")" ]]; then
        echo "\nNo unique PDFs remain in current result - removing directory"
        rmdir "${current_dir}"
        
        # Check if pdf_dir is now empty
        if [[ -z "$(ls -A "${pdf_dir}")" ]]; then
            echo "PDF output directory is empty - removing it"
            rmdir "${pdf_dir}"
        fi
    fi
else
    echo "There is no previous result, do not compare"
fi

echo "PDF creation complete"
