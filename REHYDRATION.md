# HRVSpark Workspace: REHYDRATION

This document defines the essential context and operational rules for the **HRVSpark** workspace. 

---

## ⚠️ Critical Backup Protocol (FATAL ERROR IF IGNORED)

**We recently suffered a severe, but recoverable data loss incident. To permanently mitigate this risk, a strict GitHub backup protocol is now in effect.**

1. **GitHub is the Source of Truth:** The repository is now connected to `origin/main` on GitHub.
2. **Commit and Push Frequently:** You MUST frequently commit your working changes to the local Git repository and **push to GitHub (`git push`)**.
3. **End of Task Requirement:** Before completing any significant task, concluding a working session, or handing back control to the user, you MUST ensure all changes are committed and successfully pushed to the `origin` remote.
4. **No Excuses:** A functional `git status` should always reflect a clean working directory before you stop safely. If a commit or push fails, you must alert the user immediately.

## ⚠️ Standard Safety Rules
1. **3-Strike Rule**: Stop and ask for input after 3 consecutive failures of the same command/test.
2. **Surgical Edits**: Use targeted replacements; do not rewrite large files.
3. **Terminal Safety**: Avoid interactive commands and pagers. Use `safe_exec` for long-running commands.
