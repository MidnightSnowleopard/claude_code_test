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
    # COMP_CWORD is only set during actual tab completion, not direct calls
    [[ -z ${COMP_CWORD+x} ]] && return 1

    local cur="${COMP_WORDS[COMP_CWORD]}"

    # Enable filename-style completion so bash automatically escapes spaces
    compopt -o filenames 2>/dev/null || true

    # First argument: path key (suggest available keys)
    if [ "$COMP_CWORD" -eq 1 ]; then
        local keys="${!_FILE_ORGANIZER_BASE_PATHS[@]}"
        COMPREPLY=($(compgen -W "$keys" -- "$cur"))
        return 0

    # Second argument: file pattern (no suggestions - user enters pattern freely)
    elif [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=()
        return 0

    # Third argument: folder name - suggest from existing folders using path key
    elif [ "$COMP_CWORD" -eq 3 ]; then
        local path_key="${COMP_WORDS[1]}"
        local base_path="${_FILE_ORGANIZER_BASE_PATHS[$path_key]}"

        if [ -n "$base_path" ] && [ -d "$base_path" ]; then
            # mapfile reads line-by-line so directory names with spaces stay intact
            mapfile -t COMPREPLY < <(cd "$base_path" 2>/dev/null && compgen -d -- "$cur")
        fi
        return 0

    # Fourth argument: season number - suggest existing seasons from show folder
    elif [ "$COMP_CWORD" -eq 4 ]; then
        local path_key="${COMP_WORDS[1]}"
        local show_name="${COMP_WORDS[3]}"
        local base_path="${_FILE_ORGANIZER_BASE_PATHS[$path_key]}"

        if [ -n "$base_path" ] && [ -n "$show_name" ]; then
            local show_dir="${base_path}/${show_name}"

            if [ -d "$show_dir" ]; then
                # Find existing "Season X" directories and extract numbers
                local seasons=()
                local season_dir
                while IFS= read -r -d '' season_dir; do
                    local season_name=$(basename "$season_dir")
                    # Extract number from "Season X" format
                    if [[ "$season_name" =~ ^Season\ ([0-9]+)$ ]]; then
                        seasons+=("${BASH_REMATCH[1]}")
                    fi
                done < <(find "$show_dir" -maxdepth 1 -type d -name "Season *" -print0 2>/dev/null)

                # Sort numerically and add next season
                if [ ${#seasons[@]} -gt 0 ]; then
                    local sorted=($(printf '%s\n' "${seasons[@]}" | sort -n))
                    local max_season="${sorted[-1]}"
                    local next_season=$((max_season + 1))
                    seasons+=("$next_season")
                else
                    # No existing seasons, suggest 1
                    seasons=("1")
                fi

                # Generate completions matching current input
                COMPREPLY=($(compgen -W "${seasons[*]}" -- "$cur"))
            else
                # Show directory doesn't exist yet, suggest season 1
                COMPREPLY=($(compgen -W "1" -- "$cur"))
            fi
        fi
        return 0
    fi

    return 0
}

# Register completion for different invocation methods
complete -F _file_organizer_complete file_organizer.sh
complete -F _file_organizer_complete ./file_organizer.sh
complete -F _file_organizer_complete /home/user/claude_code_test/file_organizer.sh
