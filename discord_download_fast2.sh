#!/bin/zsh

# Configuration
DOWNLOAD_DIR="${PWD}/discord_download"
IMAGES_DIR="${DOWNLOAD_DIR}/images"
ERROR_LOG="${DOWNLOAD_DIR}/failed_downloads.log"
PROGRESS_LOG="${DOWNLOAD_DIR}/progress.log"
SLEEP_DURATION=0.5
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
    echo "Total URLs:    $total_urls"
    echo "To Download:   $to_download_count"
    echo "Downloaded:    $downloaded_count"
    echo "Existing:      $existing_count"
    echo "Skipped:       $skipped_count"
    echo "Failed:        $failed_count"
    echo "Active:        $(jobs -r | wc -l)/$MAX_PARALLEL"
    echo "Current:       ${1:-None}"
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
        echo "Failed: $url" >> "$ERROR_LOG"
        return 1
    fi
}

# Preprocess URLs to separate download queue
preprocess_urls() {
    local input_file="$1"
    local download_queue=()
    local skipped_count=0
    local existing_count=0

    while read -r url; do
        [[ -z "$url" ]] && continue

        local filename="${url##*/}"
        filename="${filename%%\?*}"

        # Skip invalid patterns
        if ! is_valid_filename "$url"; then
            echo "Skipped: $filename" >> "$PROGRESS_LOG"
            ((skipped_count++))
            continue
        fi

        # Skip existing files
        if [[ -f "${IMAGES_DIR}/${filename}" ]]; then
            echo "Exists: $filename" >> "$PROGRESS_LOG"
            ((existing_count++))
            continue
        fi

        download_queue+=("$url")
    done < "$input_file"

    echo "$skipped_count" > skipped.count
    echo "$existing_count" > existing.count
    printf "%s\n" "${download_queue[@]}" > download.queue
}

# Main download function
process_downloads() {
    local failed_count=0
    local downloaded_count=0
    local to_download_count=$(wc -l < download.queue)

    while read -r url; do
        # Wait for free slot if we've reached max parallel
        while (( $(jobs -r | wc -l) >= MAX_PARALLEL )); do
            sleep 0.1
        done

        show_progress "$url"

        # Start download in background
        (
            if download_file "$url"; then
                ((downloaded_count++))
            else
                ((failed_count++))
            fi
        ) &

        sleep $SLEEP_DURATION
    done < download.queue

    wait

    echo "$downloaded_count" > downloaded.count
    echo "$failed_count" > failed.count
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

rm "${IMAGES_DIR}/*.tmp"

echo "Starting preprocessing..." | tee -a "$PROGRESS_LOG"
preprocess_urls "$1"

# Load counts
total_urls=$(wc -l < "$1")
skipped_count=$(<skipped.count)
existing_count=$(<existing.count)

echo "Starting parallel downloads..." | tee -a "$PROGRESS_LOG"
process_downloads

# Load remaining counts
downloaded_count=$(<downloaded.count)
failed_count=$(<failed.count)
to_download_count=$((downloaded_count + failed_count))

# Final summary
show_progress "Complete"
echo "\n=== Final Results ===" | tee -a "$PROGRESS_LOG"
echo "Total URLs:    $total_urls" | tee -a "$PROGRESS_LOG"
echo "Downloaded:    $downloaded_count" | tee -a "$PROGRESS_LOG"
echo "Existing:      $existing_count" | tee -a "$PROGRESS_LOG"
echo "Skipped:       $skipped_count" | tee -a "$PROGRESS_LOG"
echo "Failed:        $failed_count" | tee -a "$PROGRESS_LOG"
echo "====================" | tee -a "$PROGRESS_LOG"
echo "Download directory: $DOWNLOAD_DIR" | tee -a "$PROGRESS_LOG"
echo "Progress log: $PROGRESS_LOG" | tee -a "$PROGRESS_LOG"
echo "Error log: $ERROR_LOG" | tee -a "$PROGRESS_LOG"

# Cleanup
rm -f skipped.count existing.count downloaded.count failed.count download.queue
