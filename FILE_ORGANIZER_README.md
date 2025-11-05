# File Organizer Script

A bash script that searches for files matching a pattern, moves them to an organized directory structure, and creates both symbolic and hard links for easy access.

## Features

- **Pattern-based file search**: Uses the `find` command with customizable patterns
- **Organized file structure**: Moves files to a centralized location
- **Symbolic links**: Maintains access from original locations
- **Hard links**: Creates additional references in a parent directory
- **Collision handling**: Automatically renames files if duplicates exist
- **Color-coded output**: Easy-to-read status messages

## Usage

```bash
./file_organizer.sh <find_pattern> <folder_name>
```

### Arguments

1. **find_pattern**: The pattern to search for (e.g., `*.txt`, `*.log`, `*.jpg`)
2. **folder_name**: Name of the folder to organize files into (alphanumeric, underscore, and hyphen only)

### Example

```bash
# Organize all text files
./file_organizer.sh '*.txt' text_files

# Organize log files
./file_organizer.sh '*.log' application_logs

# Organize images
./file_organizer.sh '*.jpg' photos
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

- The script validates folder names to prevent path traversal attacks
- Uses proper quoting to handle filenames with spaces
- Uses `set -e` to exit on errors
- Provides absolute paths for symlinks

## Requirements

- Bash shell
- Standard Unix utilities: `find`, `mv`, `ln`, `realpath`
- Write permissions in target directories
