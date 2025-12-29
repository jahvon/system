#!/bin/bash

set -e

DOWNLOADS_DIR="$HOME/Downloads"
TRASH_DIR="$HOME/.Trash"
mkdir -p "$TRASH_DIR"

declare -A file_types
while IFS= read -r -d '' file; do
    ext="${file##*.}"
    file_types["$ext"]+="$file"$'\n'
done < <(find "$DOWNLOADS_DIR" -type f -print0)

echo "Files found in Downloads directory:"
for ext in "${!file_types[@]}"; do
    echo -e "\n--- $ext ---"
    echo "${file_types[$ext]}"
done

delete_files() {
    pattern="$1"
    if [[ "$pattern" == *"."* ]]; then
        # Match by extension
        ext="${pattern##*.}"
        if [[ -n "${file_types[$ext]}" ]]; then
            echo -e "\nDeleting files with .$ext extension:"
            echo "${file_types[$ext]}"
            find "$DOWNLOADS_DIR" -type f -name "*.$ext" -exec mv "{}" "$TRASH_DIR" \;
        else
            echo "No files found with .$ext extension."
        fi
    else
        # Match by full name or regex
        echo -e "\nDeleting files matching pattern: $pattern"
        find "$DOWNLOADS_DIR" -type f -name "$pattern" -exec mv "{}" "$TRASH_DIR" \;
    fi
}

while true; do
    echo "Do you want to [r]estore any files, [d]elete files, [dd]elete all, or [e]xit?"
    read -r -p "[r/d/dd/e]: " action

    case $action in
        r|R)
            echo "Enter the file name (with extension) to restore:"
            read -r file_to_restore
            if [ -f "$TRASH_DIR/$file_to_restore" ]; then
                mv "$TRASH_DIR/$file_to_restore" "$DOWNLOADS_DIR"
                echo "Restored $file_to_restore to Downloads."
            else
                echo "File not found in trash. Attempting to restore from original location."
                if [ -f "$DOWNLOADS_DIR/$file_to_restore" ]; then
                    echo "File is already in Downloads."
                else
                    echo "File not found in original location either."
                fi
            fi
            ;;
        d|D)
            echo "Enter the file extension, full name, or pattern to delete:"
            read -r pattern
            delete_files "$pattern"
            ;;
        dd|DD)
            echo "Moving all files to trash."
            find "$DOWNLOADS_DIR" -type f -exec mv "{}" "$TRASH_DIR" \;

            REVIEW_FILE="$HOME/review_list.txt"
            find "$TRASH_DIR" -type f > "$REVIEW_FILE"
            echo "Files moved to trash. Review list saved at $REVIEW_FILE"
            break
            ;;
        e|E)
            echo "Exiting. No files were moved."
            break
            ;;
        *)
            echo "Invalid option. Please enter r, d, dd, or e."
            ;;
    esac
done