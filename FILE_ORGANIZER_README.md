# File Organizer Script

A bash script that searches for files matching a pattern, moves them to an organized directory structure, and creates both symbolic and hard links for easy access.

## Features

- **Pattern-based file search**: Uses the `find` command with customizable patterns
- **Organized file structure**: Moves files to a centralized location
- **Symbolic links**: Maintains access from original locations
- **Hard links**: Creates additional references in a parent directory
- **Collision handling**: Automatically renames files if duplicates exist
- **Special character support**: Safely handles files and directories with spaces, quotes, and other special characters
- **Folder name sanitization**: Automatically sanitizes problematic characters in folder names
- **Color-coded output**: Easy-to-read status messages

## Usage

```bash
./file_organizer.sh <find_pattern> <folder_name>
```

### Arguments

1. **find_pattern**: The pattern to search for (e.g., `*.txt`, `*.log`, `*.jpg`)
2. **folder_name**: Name of the folder to organize files into (special characters will be automatically sanitized)

### Example

```bash
# Organize all text files
./file_organizer.sh '*.txt' text_files

# Organize log files
./file_organizer.sh '*.log' application_logs

# Organize images
./file_organizer.sh '*.jpg' photos

# Folder names with special characters are automatically sanitized
./file_organizer.sh '*.pdf' "My Documents: 2024/2025"
# This creates folder: /tmp/organized/My Documents_ 2024_2025
```

## How It Works

1. **Search**: Uses `find` with static arguments (`-type f -maxdepth 3`) to locate files matching the pattern
2. **Move**: Moves found files to `/tmp/organized/<folder_name>/`
3. **Symlink**: Creates symbolic link at the original location pointing to the new location
4. **Hard link**: Creates hard link in `/tmp/hardlinks/<folder_name>/`

## Directory Structure

```
/tmp/organized/<folder_name>/     # Main storage location
    ├── file1.txt
    ├── file2.txt
    └── ...

/tmp/hardlinks/<folder_name>/     # Hard link references
    ├── file1.txt
    ├── file2.txt
    └── ...
```

## Configuration

You can modify the following variables at the top of the script:

- `STATIC_BASE_PATH`: Base path for organized files (default: `/tmp/organized`)
- `HARDLINK_BASE_PATH`: Base path for hard links (default: `/tmp/hardlinks`)
- Find static arguments: Currently set to `-type f -maxdepth 3`

## Static Find Arguments

The script uses these fixed arguments for the `find` command:
- `-type f`: Only find regular files (not directories)
- `-maxdepth 3`: Limit search to 3 directory levels deep
- `-name <pattern>`: Match files using the provided pattern

## Special Character Handling

The script is designed to safely handle special characters in both filenames and directory names:

### File Names
The script correctly processes files with:
- Spaces: `file with spaces.txt`
- Single quotes: `file'with'quotes.txt`
- Double quotes: `file"with"quotes.txt`
- Parentheses: `file(with)parens.txt`
- Brackets: `file[with]brackets.txt`
- Braces: `file{with}braces.txt`
- Special symbols: `@`, `#`, `$`, `&`, `;`
- Multiple dots: `file...with...dots.txt`
- Leading dashes: `-starts-with-dash.txt`

### Directory Names
Folder names are automatically sanitized for filesystem compatibility:
- Path separators (`/`, `\`) → underscore
- Wildcards (`*`, `?`) → underscore
- Quotes (`"`) → underscore
- Pipes and redirects (`|`, `<`, `>`) → underscore
- Colons (`:`) → underscore
- Leading/trailing dots and underscores are removed
- Multiple consecutive underscores are collapsed into one

Example:
```bash
# Input: "test folder: with/special*chars"
# Sanitized to: "test folder_ with_special_chars"
```

### Implementation Details
- Uses null-delimited output (`find -print0`) to safely handle newlines in filenames
- All path operations use proper quoting and the `--` separator
- Uses `printf` instead of `echo` for safe output of special characters
- Employs dedicated functions for filename parsing and collision handling

## Important Notes

- **Hard links limitation**: Hard links can only be created on the same filesystem. If the hard link creation fails, the script will continue with a warning.
- **File collisions**: If a file with the same name already exists in the target directory, the script automatically appends a counter (e.g., `file_1.txt`, `file_2.txt`).
- **Symlink behavior**: Symlinks created are absolute paths, ensuring they work regardless of current directory.
- **Permissions**: Ensure you have write permissions in the target directories.

## Error Handling

The script includes comprehensive error handling:
- Validates input arguments
- Checks for invalid folder names
- Creates target directories if they don't exist
- Reports success/error counts at completion
- Uses color-coded output for easy identification of issues

## Output

The script provides detailed, color-coded output:
- **Green**: Informational messages
- **Yellow**: Warnings
- **Red**: Errors

Example output:
```
[INFO] Starting file organization...
[INFO] Find pattern: *.txt
[INFO] Target folder: text_files
[INFO] Target directory: /tmp/organized/text_files
[INFO] Hard link directory: /tmp/hardlinks/text_files

[INFO] Searching for files matching pattern '*.txt'...
[INFO] Found 3 file(s)

[INFO] Processing: ./doc1.txt
[INFO]   → Moved to: /tmp/organized/text_files/doc1.txt
[INFO]   → Created symlink: /home/user/doc1.txt -> /tmp/organized/text_files/doc1.txt
[INFO]   → Created hard link: /tmp/hardlinks/text_files/doc1.txt

========================================
[INFO] Organization complete!
[INFO] Successfully processed: 3 file(s)
========================================
[INFO] Files organized in: /tmp/organized/text_files
[INFO] Hard links created in: /tmp/hardlinks/text_files
```

## Security Considerations

- **Path traversal prevention**: Sanitizes folder names to block path separators and null bytes
- **Proper quoting**: All variables are quoted and use `--` separators to prevent command injection
- **Safe operations**: Uses `set -e` to exit on errors
- **Absolute paths**: Symlinks use absolute paths for consistency
- **Special character protection**: Uses `printf` with format strings instead of `echo` to prevent interpretation of escape sequences
- **Null delimiter**: Uses null-delimited file lists to safely handle any filename, including those with newlines

## Requirements

- Bash shell
- Standard Unix utilities: `find`, `mv`, `ln`, `realpath`
- Write permissions in target directories
