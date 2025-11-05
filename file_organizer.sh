#!/bin/bash

# File Organizer Script
# Usage: ./file_organizer.sh <find_pattern> <folder_name>
#
# This script:
# 1. Searches the current directory for files matching the pattern
# 2. Moves found files to a target directory
# 3. Creates symlinks from original locations to new locations
# 4. Creates hard links in a parent directory
#
# Handles special characters in filenames and directory names safely

set -e  # Exit on error
shopt -s nullglob  # Handle empty globs gracefully

# Configuration
STATIC_BASE_PATH="/tmp/organized"  # Static base path for organized files
HARDLINK_BASE_PATH="/tmp/hardlinks"  # Base path for hard links (one level above)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages (handles special characters safely)
print_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

# Validate input arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <find_pattern> <folder_name>"
    echo ""
    echo "Arguments:"
    echo "  find_pattern  - Pattern to search for (e.g., '*.txt', '*.log')"
    echo "  folder_name   - Name of the folder to organize files into"
    echo ""
    echo "Example:"
    echo "  $0 '*.txt' text_files"
    exit 1
fi

FIND_PATTERN="$1"
FOLDER_NAME_RAW="$2"

# Sanitize folder name to handle special characters
# Replace problematic characters with underscores, preserve safe special chars
sanitize_folder_name() {
    local name="$1"
    # Remove leading/trailing whitespace
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"

    # Replace path separators and null bytes (security)
    name="${name//\//_}"
    name="${name//$'\0'/_}"

    # Replace other problematic characters for filesystems
    name="${name//\\/_}"
    name="${name//:/_}"
    name="${name//\*/_}"
    name="${name//\?/_}"
    name="${name//\"/_}"
    name="${name//</_}"
    name="${name//>/_}"
    name="${name//|/_}"

    # Collapse multiple underscores
    while [[ "$name" =~ __ ]]; do
        name="${name//__/_}"
    done

    # Remove leading/trailing underscores and dots
    name="${name#[_.]}"
    name="${name%[_.]}"

    # Ensure we have a valid name
    if [ -z "$name" ]; then
        name="organized_files"
    fi

    echo "$name"
}

FOLDER_NAME="$(sanitize_folder_name "$FOLDER_NAME_RAW")"

if [ "$FOLDER_NAME" != "$FOLDER_NAME_RAW" ]; then
    print_warning "Folder name sanitized from '$FOLDER_NAME_RAW' to '$FOLDER_NAME'"
fi

# Set up target directories
TARGET_DIR="${STATIC_BASE_PATH}/${FOLDER_NAME}"
HARDLINK_DIR="${HARDLINK_BASE_PATH}/${FOLDER_NAME}"

print_info "Starting file organization..."
print_info "Find pattern: $FIND_PATTERN"
print_info "Target folder: $FOLDER_NAME"
print_info "Target directory: $TARGET_DIR"
print_info "Hard link directory: $HARDLINK_DIR"
echo ""

# Create target directories if they don't exist
mkdir -p "$TARGET_DIR"
mkdir -p "$HARDLINK_DIR"

# Store the starting directory
START_DIR="$(pwd)"

# Find files matching the pattern
# Static find arguments: -type f (files only), -maxdepth 3 (limit depth)
print_info "Searching for files matching pattern '$FIND_PATTERN'..."
FOUND_FILES=()
while IFS= read -r -d $'\0' file; do
    FOUND_FILES+=("$file")
done < <(find "$START_DIR" -type f -maxdepth 3 -name "$FIND_PATTERN" -print0 2>/dev/null)

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    print_warning "No files found matching pattern '$FIND_PATTERN'"
    exit 0
fi

print_info "Found ${#FOUND_FILES[@]} file(s)"
echo ""

# Function to safely split filename into base and extension
split_filename() {
    local filename="$1"
    local base ext

    # Check if file has an extension (last dot that's not at the start)
    if [[ "$filename" =~ \. && "$filename" != .* ]]; then
        # Get extension (everything after the last dot)
        ext="${filename##*.}"
        # Get base name (everything before the last dot)
        base="${filename%.*}"

        # If the "extension" is too long (>10 chars) or empty, treat as no extension
        if [ ${#ext} -gt 10 ] || [ -z "$ext" ]; then
            base="$filename"
            ext=""
        fi
    else
        base="$filename"
        ext=""
    fi

    echo "$base"
    echo "$ext"
}

# Function to generate unique target filename
get_unique_filename() {
    local target_dir="$1"
    local base_name="$2"
    local extension="$3"
    local target_file counter

    if [ -n "$extension" ]; then
        target_file="${target_dir}/${base_name}.${extension}"
    else
        target_file="${target_dir}/${base_name}"
    fi

    counter=1
    while [ -e "$target_file" ]; do
        if [ -n "$extension" ]; then
            target_file="${target_dir}/${base_name}_${counter}.${extension}"
        else
            target_file="${target_dir}/${base_name}_${counter}"
        fi
        counter=$((counter + 1))
    done

    echo "$target_file"
}

# Process each found file
SUCCESS_COUNT=0
ERROR_COUNT=0

for file in "${FOUND_FILES[@]}"; do
    # Get absolute path of the file
    FILE_ABS_PATH="$(realpath -- "$file")"
    FILE_NAME="$(basename -- "$file")"
    FILE_DIR="$(dirname -- "$FILE_ABS_PATH")"

    print_info "Processing: $file"

    # Split filename into base and extension
    IFS=$'\n' read -r -d '' BASE_NAME EXTENSION < <(split_filename "$FILE_NAME" && printf '\0')

    # Generate unique target filename
    TARGET_FILE="$(get_unique_filename "$TARGET_DIR" "$BASE_NAME" "$EXTENSION")"

    # Move the file to target directory
    if mv -- "$FILE_ABS_PATH" "$TARGET_FILE"; then
        print_info "  → Moved to: $TARGET_FILE"

        # Create symlink from original location to new location
        if ln -s -- "$TARGET_FILE" "$FILE_ABS_PATH"; then
            print_info "  → Created symlink: $FILE_ABS_PATH -> $TARGET_FILE"
        else
            print_error "  → Failed to create symlink at $FILE_ABS_PATH"
            ERROR_COUNT=$((ERROR_COUNT + 1))
            continue
        fi

        # Create hard link in the parent directory
        HARDLINK_FILE="$HARDLINK_DIR/$(basename -- "$TARGET_FILE")"
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
