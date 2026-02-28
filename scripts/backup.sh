#!/bin/bash

# HRVSpark Backup Script
# Creates a timestamped zip archive of the project, excluding build artifacts.

PROJECT_NAME="HRVSpark"
PROJECT_DIR="/Users/joelfarthing/Library/Mobile Documents/com~apple~CloudDocs/Xcode Projects/HRVSpark"
BACKUP_ROOT="$PROJECT_DIR/Backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="${PROJECT_NAME}_${TIMESTAMP}.zip"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_ROOT"

echo "Creating backup: $FILENAME..."

# Change to project directory to ensure paths in zip are relative
cd "$PROJECT_DIR" || exit

# Create the zip archive
# Exclusions:
# - Backups/ (don't zip previous backups)
# - .git/ (git history is already preserved, this is a source snapshot)
# - DerivedData/ and build/ (temp build files)
# - *.xcuserstate (user-specific UI state)
# - .DS_Store (macOS noise)

zip -r "$BACKUP_ROOT/$FILENAME" . \
    -x "Backups/*" \
    -x ".git/*" \
    -x "**/DerivedData/*" \
    -x "**/build/*" \
    -x "*.xcuserstate" \
    -x "**/.DS_Store" \
    -x ".agent/*" # Exclude agent state to keep it pure source

if [ $? -eq 0 ]; then
    echo "------------------------------------------------"
    echo "Backup successful!"
    echo "Location: $BACKUP_ROOT/$FILENAME"
    echo "Size: $(du -h "$BACKUP_ROOT/$FILENAME" | cut -f1)"
    echo "------------------------------------------------"
else
    echo "Backup failed!"
    exit 1
fi
