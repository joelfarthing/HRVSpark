---
description: Create a timestamped backup of the HRVSpark project
---

This workflow triggers the backup script to create a compressed snapshot of the current project state, excluding build artifacts and temporary files.

### Steps

1. **Run the backup script**
// turbo
```bash
bash "/Users/joelfarthing/Library/Mobile Documents/com~apple~CloudDocs/Xcode Projects/HRVSpark/scripts/backup.sh"
```

2. **Verify the backup**
You can find the backup in the `Backups/` directory within the project root.
