#!/bin/zsh

# Configuration
DOWNLOAD_DIR="${PWD}/discord_download"
IMAGES_DIR="${DOWNLOAD_DIR}/images"
ERROR_LOG="${DOWNLOAD_DIR}/failed_downloads.log"
PROGRESS_LOG="${DOWNLOAD_DIR}/progress.log"
SLEEP_DURATION=1.5
MAX_PARALLEL=4  # Number of concurrent downloads

# Create directories
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$IMAGES_DIR"
: > "$ERROR_LOG"
: > "$PROGRESS_LOG"

# Function to show progress
show_progress() {
    clear
    echo "\n=== Download Progress ==="
    echo "Total URLs:    $(wc -l < "$1")"
    echo "Processed:     $(grep -c "Processed:" "$PROGRESS_LOG")"
    echo "Existing:      $(grep -c "Exists:" "$PROGRESS_LOG")"
    echo "Skipped:       $(grep -c "Skipped:" "$PROGRESS_LOG")"
    echo "Failed:        $(grep -c "Failed:" "$PROGRESS_LOG")"
    echo 'Active:        '$(( $(ps aux | grep "curl -s -L -o ${IMAGES_DIR}" | wc -l)-1 ))'/'$MAX_PARALLEL
    echo "Current:       $2"
    echo "========================"
}

# Function to check filename pattern
is_valid_filename() {
    local filename="${1##*/}"
    filename="${filename%%\?*}"
    [[ "$filename" =~ '^([[:alnum:]]+_)?[0-9]+-[0-9]+\.(png|jpg|webp)$' ]]
}

# Function to transform URL
transform_url() {
    local url="${1//media.discordapp.net/cdn.discordapp.com}"
    url="${url%%&width=*}"
    url="${url%%=}"
    url="${url%%\?}"
    echo "$url"
}

# Function to download a file
download_file() {
    local url="$1"
    local transformed_url=$(transform_url "$url")
    local filename="${transformed_url##*/}"
    filename="${filename%%\?*}"

    # Check if file exists
    if [[ -f "${IMAGES_DIR}/${filename}" ]]; then
        echo "Exists: $filename" >> "$PROGRESS_LOG"
        return 2
    fi

    # Create temp file to prevent duplicate downloads
    local tempfile="${IMAGES_DIR}/${filename}.tmp"
    if ! (set -o noclobber; echo "$$" > "$tempfile") 2>/dev/null; then
        return 3  # Already being downloaded by another process
    fi

    # Actual download
    if curl -s -L -o "${IMAGES_DIR}/${filename}" \
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
        "$transformed_url"; then
        rm -f "$tempfile"
        echo "Downloaded: $filename" >> "$PROGRESS_LOG"
        return 0
    else
        rm -f "$tempfile" "${IMAGES_DIR}/${filename}" 2>/dev/null
        echo "Failed to download ${url} as transformed ${transformed_url}" >> "$ERROR_LOG"
        return 1
    fi
}

# Worker function
process_url() {
    local url="$1"
    local filename="${url##*/}"
    filename="${filename%%\?*}"

    # Skip invalid patterns
    if ! is_valid_filename "$url"; then
        echo "Skipped: $filename" >> "$PROGRESS_LOG"
        return
    fi

    echo "Processed: $filename" >> "$PROGRESS_LOG"

    download_file "$url"
    return $?
}

# Main function
main() {
    local input_file="$1"
    local current_url

    while read -r current_url; do
        [[ -z "$current_url" ]] && continue

        # Wait for free slot if we've reached max parallel
        while (( $(ps aux | grep "curl -s -L -o ${IMAGES_DIR}" | wc -l) > $MAX_PARALLEL )); do
            show_progress "$input_file" "Sleep $SLEEP_DURATION to get $current_url"
            sleep $SLEEP_DURATION
        done

        # Show progress
        show_progress "$input_file" "$current_url"

        # Start download in background
        process_url "$current_url" &
    done < "$input_file"

    # Wait for all background jobs
    wait
}

# Execution
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <input_file>" >&2
    exit 1
fi

if [[ ! -f "$1" ]]; then
    echo "Error: Input file not found: $1" >&2
    exit 1
fi

# find "${IMAGES_DIR}" -maxdepth 1 -type f -name '*.tmp'
# echo "Existing now"
# sleep 10
find "${IMAGES_DIR}" -maxdepth 1 -type f -name '*.tmp' -print -delete
# echo "Deleted"
# sleep 2
# find "${IMAGES_DIR}" -maxdepth 1 -type f -name '*.tmp'
# echo "After delete"
# sleep 15

echo "Starting parallel download process..." | tee -a "$PROGRESS_LOG"
main "$1"

# Final summary
echo "\n=== Final Results ===" | tee -a "$PROGRESS_LOG"
echo "Total URLs:    $(wc -l < "$1")" | tee -a "$PROGRESS_LOG"
echo "Processed:     $(grep -c "Processed:" "$PROGRESS_LOG")" | tee -a "$PROGRESS_LOG"
echo "Existing:      $(grep -c "Exists:" "$PROGRESS_LOG")" | tee -a "$PROGRESS_LOG"
echo "Skipped:       $(grep -c "Skipped:" "$PROGRESS_LOG")" | tee -a "$PROGRESS_LOG"
echo "Failed:        $(grep -c "Failed:" "$ERROR_LOG")" | tee -a "$PROGRESS_LOG"
echo "====================" | tee -a "$PROGRESS_LOG"
echo "Download directory: $DOWNLOAD_DIR" | tee -a "$PROGRESS_LOG"
echo "Progress log: $PROGRESS_LOG" | tee -a "$PROGRESS_LOG"
echo "Error log: $ERROR_LOG" | tee -a "$PROGRESS_LOG"
