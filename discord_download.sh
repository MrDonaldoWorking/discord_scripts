#!/bin/zsh

# Configuration
DIRECTORY="${PWD}/discord_download"
IMG_DIR="${DIRECTORY}/images"
ERROR_LOG="${DIRECTORY}/discord_download_fails.log"
PROGRESS_LOG="${DIRECTORY}/discord_download_progress.log"
SLEEP_DURATION=1  # seconds between downloads

# Initialize counters
TOTAL=0
PROCESSED=0
SKIPPED=0
FAILED=0
EXISTING=0

# Function to update and display progress
show_progress() {
    clear
    echo "\n=== Download Progress ==="
    echo "Total URLs:    $TOTAL"
    echo "Processed:     $PROCESSED"
    echo "Existing:      $EXISTING"
    echo "Skipped:       $SKIPPED"
    echo "Failed:        $FAILED"
    echo "Current:       $1"
    echo "========================"
}

# Function to check if filename matches the pattern
is_valid_filename() {
    local url="$1"
    local filename=$(basename "$url")
    filename="${filename%%\?*}"  # Remove query parameters
    
    # Check if filename matches the pattern
    [[ "$filename" =~ ^([[:alnum:]]+_)?[0-9]+-[0-9]+\.(png|jpg|webp)$ ]]
}

# Function to check if file exists
file_exists() {
    local filename="$1"
    [ -f "${IMG_DIR}/${filename}" ] && return 0 || return 1
}

# Function to transform the URL
transform_url() {
    local url="$1"
    # Replace media.discordapp.net with cdn.discordapp.com
    url="${url//media.discordapp.net/cdn.discordapp.com}"
    # Remove width and height parameters and any trailing ampersand
    url="${url%&width=*}"
    # If there's a trailing '&', remove it
    url="${url%&}"
    # If there's a trailing '?', remove it
    url="${url%\?}"
    # If there's a trailing '=', remove it
    url="${url%=}"
    echo "$url"
}

# Function to download a single file
download_file() {
    local original_url="$1"
    local transformed_url=$(transform_url "$original_url")
    local filename=$(basename "$transformed_url")
    filename="${filename%%\?*}"  # Remove query parameters from filename

    # Check if file already exists
    if file_exists "$filename"; then
        ((EXISTING++))
        show_progress "Already exists: $filename" | tee -a "$PROGRESS_LOG"
        return 2
    fi

    show_progress "Downloading: $filename" | tee -a "$PROGRESS_LOG"

    curl -s -L -o "${IMG_DIR}/$filename" \
        -X 'GET' \
        -H 'Accept: image/webp,image/avif,image/jxl,image/heic,image/heic-sequence,video/*;q=0.8,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5' \
        -H 'Sec-Fetch-Site: cross-site' \
        -H 'Sec-Fetch-Dest: image' \
        -H 'Accept-Language: en-US,en;q=0.9' \
        -H 'Sec-Fetch-Mode: no-cors' \
        -H 'Host: cdn.discordapp.com' \
        -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15' \
        -H 'Referer: https://discord.com/' \
        -H 'Accept-Encoding: gzip, deflate, br' \
        -H 'Connection: keep-alive' \
        "$transformed_url"

    if [ $? -ne 0 ]; then
        echo "$original_url" >> "$ERROR_LOG"
        echo "Failed to download: $original_url" >&2
        return 1
    else
        echo "Successfully downloaded: $filename" | tee -a "$PROGRESS_LOG"
        return 0
    fi
}

echo "Reading links passed from FIRST ARGUMENT: $1"

# Main processing function
process_urls() {
    local input_file="$1"
    
    # Count total valid URLs first
    while read -r url; do
        [ -z "$url" ] && continue
        if is_valid_filename "$url"; then
            ((TOTAL++))
        fi
    done < "$input_file"

    echo "Found $TOTAL valid URLs to process" | tee -a "$PROGRESS_LOG"
    
    # Process each URL
    while read -r url; do
        [ -z "$url" ] && continue

        if ! is_valid_filename "$url"; then
            ((SKIPPED++))
            show_progress "Skipping: ${url##*/}"
            continue
        fi

        ((PROCESSED++))
        download_file "$url"
        case $? in
            0) ;;  # Success
            1) ((FAILED++)) ;;
            2) ((EXISTING++)) ;;
        esac

        sleep $SLEEP_DURATION
    done < "$input_file"
}

# Main execution
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>" >&2
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: Input file not found: $1" >&2
    exit 1
fi

mkdir -p "$DIRECTORY"
mkdir -p "$IMG_DIR"

# Clear previous logs
: > "$ERROR_LOG"
: > "$PROGRESS_LOG"

echo "Starting download process..." | tee -a "$PROGRESS_LOG"
process_urls "$1"

# Final summary
echo "\n=== Final Results ===" | tee -a "$PROGRESS_LOG"
echo "Total URLs:    $TOTAL" | tee -a "$PROGRESS_LOG"
echo "Processed:     $PROCESSED" | tee -a "$PROGRESS_LOG"
echo "Existing:      $EXISTING" | tee -a "$PROGRESS_LOG"
echo "Skipped:       $SKIPPED" | tee -a "$PROGRESS_LOG"
echo "Failed:        $FAILED" | tee -a "$PROGRESS_LOG"
echo "====================" | tee -a "$PROGRESS_LOG"
echo "Download directory: $DIRECTORY"
echo "Progress log: $PROGRESS_LOG"
echo "Error log:    $ERROR_LOG"
