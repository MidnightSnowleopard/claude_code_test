#!/bin/bash

# File Organizer Script
# Usage: ./file_organizer.sh <path_key> <find_pattern> <folder_name>
#
# This script:
# 1. Searches the current directory for files matching the pattern
# 2. Moves found files to a pre-defined base directory selected by key
# 3. Creates relative symlinks from original locations to new locations
# 4. Creates hard links in a parallel directory structure
#
# All inputs are treated as literal strings with proper quoting

set -e  # Exit on error

# Pre-defined base paths - customize these for your needs
declare -A BASE_PATHS=(
    ["temp"]="/tmp/organized"
    ["archives"]="/home/user/archives"
    ["documents"]="/home/user/Documents/organized"
    ["downloads"]="/home/user/Downloads/organized"
    ["media"]="/home/user/media/organized"
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    printf '%b[INFO]%b %s\n' "${GREEN}" "${NC}" "$1"
}

print_error() {
    printf '%b[ERROR]%b %s\n' "${RED}" "${NC}" "$1"
}

print_warning() {
    printf '%b[WARNING]%b %s\n' "${YELLOW}" "${NC}" "$1"
}

# Function to calculate relative path from one directory to another
# Usage: get_relative_path FROM TO
get_relative_path() {
    local from="$1"
    local to="$2"
    local common up result

    # Normalize paths (remove trailing slashes)
    from="${from%/}"
    to="${to%/}"

    # Split paths into arrays
    IFS='/' read -ra from_parts <<< "$from"
    IFS='/' read -ra to_parts <<< "$to"

    # Find common prefix
    local common_parts=0
    local max_parts=${#from_parts[@]}
    [ ${#to_parts[@]} -lt $max_parts ] && max_parts=${#to_parts[@]}

    for ((i=0; i<max_parts; i++)); do
        if [ "${from_parts[$i]}" = "${to_parts[$i]}" ]; then
            common_parts=$((i + 1))
        else
            break
        fi
    done

    # Build relative path
    result=""

    # Add ../ for each remaining part in from_parts
    for ((i=common_parts; i<${#from_parts[@]}; i++)); do
        result="${result}../"
    done

    # Add remaining parts from to_parts
    for ((i=common_parts; i<${#to_parts[@]}; i++)); do
        result="${result}${to_parts[$i]}/"
    done

    # Remove trailing slash
    result="${result%/}"

    # If result is empty, paths are the same
    [ -z "$result" ] && result="."

    echo "$result"
}

# Validate input arguments
if [ $# -ne 3 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <path_key> <find_pattern> <folder_name>"
    echo ""
    echo "Arguments:"
    echo "  path_key      - Key for pre-defined base path (available: ${!BASE_PATHS[@]})"
    echo "  find_pattern  - Pattern to search for (e.g., '*.txt', '*.log')"
    echo "  folder_name   - Name of the folder to organize files into"
    echo ""
    echo "Available path keys:"
    for key in "${!BASE_PATHS[@]}"; do
        echo "  $key -> ${BASE_PATHS[$key]}"
    done
    echo ""
    echo "Examples:"
    echo "  $0 temp '*.txt' text_files"
    echo "  $0 archives '*.log' app_logs"
    exit 1
fi

PATH_KEY="$1"
FIND_PATTERN="$2"
FOLDER_NAME="$3"

# Validate path key exists
if [ -z "${BASE_PATHS[$PATH_KEY]}" ]; then
    print_error "Invalid path key: $PATH_KEY"
    echo "Available keys: ${!BASE_PATHS[@]}"
    exit 1
fi

# Get the actual base path from the key
BASE_PATH="${BASE_PATHS[$PATH_KEY]}"

# Validate base path exists, create if needed
if [ ! -d "$BASE_PATH" ]; then
    print_warning "Base path does not exist: $BASE_PATH"
    echo "Creating directory..."
    mkdir -p "$BASE_PATH"
    print_info "Created: $BASE_PATH"
fi

# Minimal folder name validation - only reject path separators for security
if [[ "$FOLDER_NAME" == */* ]]; then
    print_error "Folder name cannot contain path separators"
    exit 1
fi

# Set up target directories (use .staging subfolder for hardlinks)
TARGET_DIR="${BASE_PATH}/${FOLDER_NAME}"
HARDLINK_DIR="${BASE_PATH}/.staging/${FOLDER_NAME}"

print_info "Starting file organization..."
print_info "Path key: $PATH_KEY"
print_info "Base path: $BASE_PATH"
print_info "Find pattern: $FIND_PATTERN"
print_info "Target folder: $FOLDER_NAME"
print_info "Target directory: $TARGET_DIR"
print_info "Hard link directory: $HARDLINK_DIR"
echo ""

# Create target directories if they don't exist
mkdir -p -- "$TARGET_DIR"
mkdir -p -- "$HARDLINK_DIR"

# Store the starting directory
START_DIR="$(pwd)"

# Find files matching the pattern
# Static find arguments: -type f (files only), -maxdepth 3 (limit depth)
print_info "Searching for files matching pattern '$FIND_PATTERN'..."
FOUND_FILES=()
while IFS= read -r -d '' file; do
    FOUND_FILES+=("$file")
done < <(find "$START_DIR" -type f -maxdepth 3 -iname "$FIND_PATTERN" -print0 2>/dev/null)

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    print_warning "No files found matching pattern '$FIND_PATTERN'"
    exit 0
fi

print_info "Found ${#FOUND_FILES[@]} file(s)"
echo ""

# Process each found file
SUCCESS_COUNT=0
ERROR_COUNT=0

for file in "${FOUND_FILES[@]}"; do
    # Get file information - all as literal strings
    FILE_ABS_PATH="$(realpath "$file")"
    FILE_NAME="$(basename -- "$file")"

    print_info "Processing: $file"

    # Target file path - use filename as-is
    TARGET_FILE="${TARGET_DIR}/${FILE_NAME}"

    # Handle collision - append counter if file exists
    COUNTER=1
    while [ -e "$TARGET_FILE" ]; do
        TARGET_FILE="${TARGET_DIR}/${FILE_NAME}.${COUNTER}"
        COUNTER=$((COUNTER + 1))
    done

    # Move the file to target directory
    if mv -- "$FILE_ABS_PATH" "$TARGET_FILE"; then
        print_info "  → Moved to: $TARGET_FILE"

        # Create symlink from original location to new location (using relative path)
        RELATIVE_TARGET="$(get_relative_path "$(dirname "$FILE_ABS_PATH")" "$TARGET_FILE")"
        if ln -s -- "$RELATIVE_TARGET" "$FILE_ABS_PATH"; then
            print_info "  → Created symlink: $FILE_ABS_PATH -> $RELATIVE_TARGET"
        else
            print_error "  → Failed to create symlink at $FILE_ABS_PATH"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            continue
        fi

        # Create hard link in the parent directory
        HARDLINK_FILE="${HARDLINK_DIR}/$(basename -- "$TARGET_FILE")"
        if ln -- "$TARGET_FILE" "$HARDLINK_FILE" 2>/dev/null; then
            print_info "  → Created hard link: $HARDLINK_FILE"
        else
            print_warning "  → Could not create hard link (file may be on different filesystem)"
        fi

        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo ""
    else
        print_error "  → Failed to move file"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        echo ""
    fi
done

# Summary
echo "========================================"
print_info "Organization complete!"
print_info "Successfully processed: $SUCCESS_COUNT file(s)"
if [ $ERROR_COUNT -gt 0 ]; then
    print_error "Errors encountered: $ERROR_COUNT"
fi
echo "========================================"
print_info "Files organized in: $TARGET_DIR"
print_info "Hard links created in: $HARDLINK_DIR"
