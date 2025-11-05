#!/bin/bash

# File Organizer Script
# Usage: ./file_organizer.sh <find_pattern> <folder_name>
#
# This script:
# 1. Searches the current directory for files matching the pattern
# 2. Moves found files to a target directory
# 3. Creates relative symlinks from original locations to new locations
# 4. Creates hard links in a parent directory
#
# All inputs are treated as literal strings with proper quoting

set -e  # Exit on error

# Configuration
STATIC_BASE_PATH="/tmp/organized"  # Static base path for organized files
HARDLINK_BASE_PATH="/tmp/hardlinks"  # Base path for hard links (one level above)

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
FOLDER_NAME="$2"

# Minimal folder name validation - only reject path separators for security
if [[ "$FOLDER_NAME" == */* ]]; then
    print_error "Folder name cannot contain path separators"
    exit 1
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
done < <(find "$START_DIR" -type f -maxdepth 3 -name "$FIND_PATTERN" -print0 2>/dev/null)

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
    FILE_ABS_PATH="$(realpath -- "$file")"
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
        RELATIVE_TARGET="$(realpath --relative-to="$(dirname -- "$FILE_ABS_PATH")" -- "$TARGET_FILE")"
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
