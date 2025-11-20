#!/bin/bash
# Bash completion for file_organizer.sh
#
# Installation:
#   Add to ~/.bashrc:
#     source /path/to/file_organizer_completion.bash
#
# Or copy to bash completion directory:
#   Linux: ~/.bash_completion.d/ or /etc/bash_completion.d/
#   FreeBSD: /usr/local/share/bash-completion/completions/

# Pre-defined base paths - MUST match those in file_organizer.sh
declare -A _FILE_ORGANIZER_BASE_PATHS=(
    ["temp"]="/tmp/organized"
    ["archives"]="/home/user/archives"
    ["documents"]="/home/user/Documents/organized"
    ["downloads"]="/home/user/Downloads/organized"
    ["media"]="/home/user/media/organized"
)

_file_organizer_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    # First argument: path key (suggest available keys)
    if [ $COMP_CWORD -eq 1 ]; then
        local keys="${!_FILE_ORGANIZER_BASE_PATHS[@]}"
        COMPREPLY=($(compgen -W "$keys" -- "$cur"))
        return 0

    # Second argument: file pattern (no suggestions - user enters pattern freely)
    elif [ $COMP_CWORD -eq 2 ]; then
        COMPREPLY=()
        return 0

    # Third argument: folder name - suggest from existing folders using path key
    elif [ $COMP_CWORD -eq 3 ]; then
        local path_key="${COMP_WORDS[1]}"
        local base_path="${_FILE_ORGANIZER_BASE_PATHS[$path_key]}"

        # Check if base path exists and is a directory
        if [ -n "$base_path" ] && [ -d "$base_path" ]; then
            # List subdirectories in the base path
            # Use array to properly handle spaces and special characters
            local folder
            COMPREPLY=()
            while IFS= read -r -d '' folder; do
                # Remove trailing slash
                folder="${folder%/}"
                # Get just the basename
                folder="$(basename "$folder")"
                # Check if it matches the current input
                if [[ "$folder" == "$cur"* ]]; then
                    COMPREPLY+=("$folder")
                fi
            done < <(cd "$base_path" 2>/dev/null && find . -maxdepth 1 -type d ! -name '.' -print0 2>/dev/null)
            return 0
        fi
    fi

    return 0
}

# Register completion for different invocation methods
complete -F _file_organizer_complete file_organizer.sh
complete -F _file_organizer_complete ./file_organizer.sh
complete -F _file_organizer_complete /home/user/claude_code_test/file_organizer.sh
