#!/bin/bash
# Debug version of completion - Run this to test what's happening
# Usage: source this file, then try completion

# Pre-defined base paths - MUST match those in file_organizer.sh
declare -A _FILE_ORGANIZER_BASE_PATHS=(
    ["temp"]="/tmp/organized"
    ["archives"]="/home/user/archives"
    ["documents"]="/home/user/Documents/organized"
    ["downloads"]="/home/user/Downloads/organized"
    ["media"]="/home/user/media/organized"
)

_file_organizer_complete_debug() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Debug output
    echo "" >&2
    echo "=== DEBUG ===" >&2
    echo "COMP_CWORD: $COMP_CWORD" >&2
    echo "cur: '$cur'" >&2
    echo "prev: '$prev'" >&2
    echo "All words: ${COMP_WORDS[@]}" >&2

    # First argument: path key (suggest available keys)
    if [ $COMP_CWORD -eq 1 ]; then
        echo "Branch: First argument (path key)" >&2
        local keys="${!_FILE_ORGANIZER_BASE_PATHS[@]}"
        echo "Available keys: $keys" >&2
        COMPREPLY=($(compgen -W "$keys" -- "$cur"))
        echo "COMPREPLY: ${COMPREPLY[@]}" >&2

    # Second argument: file pattern (no suggestions)
    elif [ $COMP_CWORD -eq 2 ]; then
        echo "Branch: Second argument (pattern - no suggestions)" >&2
        COMPREPLY=()
        echo "COMPREPLY: empty (intentional)" >&2
        return

    # Third argument: folder name
    elif [ $COMP_CWORD -eq 3 ]; then
        echo "Branch: Third argument (folder name)" >&2
        local path_key="${COMP_WORDS[1]}"
        echo "path_key from COMP_WORDS[1]: '$path_key'" >&2

        local base_path="${_FILE_ORGANIZER_BASE_PATHS[$path_key]}"
        echo "base_path lookup result: '$base_path'" >&2

        # Check if base path exists and is a directory
        if [ -n "$base_path" ]; then
            echo "base_path is not empty" >&2
            if [ -d "$base_path" ]; then
                echo "base_path exists as directory" >&2
                # List subdirectories in the base path
                local folders=$(cd "$base_path" 2>/dev/null && ls -d */ 2>/dev/null | sed 's#/##')
                echo "Found folders: $folders" >&2
                COMPREPLY=($(compgen -W "$folders" -- "$cur"))
                echo "COMPREPLY: ${COMPREPLY[@]}" >&2
            else
                echo "base_path does NOT exist as directory" >&2
                COMPREPLY=()
            fi
        else
            echo "base_path is empty - invalid key?" >&2
            COMPREPLY=()
        fi
    fi

    echo "=== END DEBUG ===" >&2
    echo "" >&2
}

# Test the array first
echo "Testing associative array:"
echo "Keys: ${!_FILE_ORGANIZER_BASE_PATHS[@]}"
echo "temp -> ${_FILE_ORGANIZER_BASE_PATHS[temp]}"
echo ""

# Register debug completion
complete -F _file_organizer_complete_debug file_organizer.sh
complete -F _file_organizer_complete_debug ./file_organizer.sh

echo "Debug completion loaded. Try: ./file_organizer.sh <TAB>"
echo "Debug output will appear on stderr"
