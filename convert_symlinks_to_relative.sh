#!/bin/bash

# Symlink Converter Script
# Usage: ./convert_symlinks_to_relative.sh <search_pattern> [search_path]
#
# This script:
# 1. Searches for symbolic links matching a pattern in the specified path
# 2. Identifies absolute symlinks
# 3. Converts them to relative symlinks
#
# All inputs are treated as literal strings with proper quoting

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_success() {
    printf '%b[SUCCESS]%b %s\n' "${BLUE}" "${NC}" "$1"
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
if [ $# -eq 0 ]; then
    print_error "Missing required argument: search_pattern"
    echo "Usage: $0 <search_pattern> [search_path]"
    echo ""
    echo "Arguments:"
    echo "  search_pattern  - Pattern to search for symlinks (e.g., '*.txt', '*link*')"
    echo "  search_path     - Directory to search (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  $0 '*.txt'"
    echo "  $0 '*link*' /path/to/search"
    exit 1
elif [ $# -eq 1 ]; then
    SEARCH_PATTERN="$1"
    SEARCH_PATH="."
elif [ $# -eq 2 ]; then
    SEARCH_PATTERN="$1"
    SEARCH_PATH="$2"
else
    print_error "Too many arguments"
    echo "Usage: $0 <search_pattern> [search_path]"
    exit 1
fi

# Validate search path exists
if [ ! -d "$SEARCH_PATH" ]; then
    print_error "Search path does not exist or is not a directory: $SEARCH_PATH"
    exit 1
fi

# Get absolute path of search directory
SEARCH_PATH_ABS="$(realpath "$SEARCH_PATH")"

print_info "Starting symlink conversion..."
print_info "Search pattern: $SEARCH_PATTERN"
print_info "Search path: $SEARCH_PATH_ABS"
echo ""

# Find symbolic links matching the pattern
print_info "Searching for symbolic links matching pattern '$SEARCH_PATTERN'..."
FOUND_LINKS=()
while IFS= read -r -d '' link; do
    FOUND_LINKS+=("$link")
done < <(find "$SEARCH_PATH_ABS" -type l -name "$SEARCH_PATTERN" -print0 2>/dev/null)

if [ ${#FOUND_LINKS[@]} -eq 0 ]; then
    print_warning "No symbolic links found matching pattern '$SEARCH_PATTERN' in $SEARCH_PATH_ABS"
    exit 0
fi

print_info "Found ${#FOUND_LINKS[@]} symbolic link(s)"
echo ""

# Process each symbolic link
CONVERTED_COUNT=0
ALREADY_RELATIVE_COUNT=0
BROKEN_LINK_COUNT=0
ERROR_COUNT=0

for link in "${FOUND_LINKS[@]}"; do
    # Get the link target
    LINK_TARGET="$(readlink -- "$link")"

    print_info "Checking: $link"
    print_info "  Current target: $LINK_TARGET"

    # Check if link target is absolute (starts with /)
    if [[ "$LINK_TARGET" == /* ]]; then
        print_info "  → Absolute symlink detected"

        # Check if the target exists
        if [ ! -e "$link" ]; then
            print_warning "  → Target does not exist (broken link), skipping conversion"
            BROKEN_LINK_COUNT=$((BROKEN_LINK_COUNT + 1))
            echo ""
            continue
        fi

        # Get absolute path of the target
        TARGET_ABS="$(realpath "$link")"

        # Get directory containing the symlink
        LINK_DIR="$(dirname "$link")"

        # Calculate relative path from link location to target
        RELATIVE_TARGET="$(get_relative_path "$LINK_DIR" "$TARGET_ABS")"

        # Remove the old symlink and create new relative one
        if rm -- "$link" && ln -s -- "$RELATIVE_TARGET" "$link"; then
            print_success "  → Converted to relative: $RELATIVE_TARGET"
            CONVERTED_COUNT=$((CONVERTED_COUNT + 1))
        else
            print_error "  → Failed to convert symlink"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    else
        print_info "  → Already relative, no conversion needed"
        ALREADY_RELATIVE_COUNT=$((ALREADY_RELATIVE_COUNT + 1))
    fi

    echo ""
done

# Summary
echo "========================================"
print_info "Conversion complete!"
print_success "Converted to relative: $CONVERTED_COUNT symlink(s)"
print_info "Already relative: $ALREADY_RELATIVE_COUNT symlink(s)"
if [ $BROKEN_LINK_COUNT -gt 0 ]; then
    print_warning "Broken links skipped: $BROKEN_LINK_COUNT"
fi
if [ $ERROR_COUNT -gt 0 ]; then
    print_error "Errors encountered: $ERROR_COUNT"
fi
echo "========================================"
