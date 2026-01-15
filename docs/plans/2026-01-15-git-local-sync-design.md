# Git Local Sync Script Design

## Overview

A bash script to sync the main branch from a local backup repository without network access. Designed for a feature branch workflow where main is kept clean.

## Use Case

- **repo_1**: Working repository with feature branches
- **repo_2**: Backup/mirror repository that gets updated externally (e.g., copied from another machine)
- **Workflow**: Work on feature branches, keep main clean, periodically sync main from repo_2

## Architecture

### Script Location
`scripts/git-sync-local.sh`

### Basic Flow
1. Take repo_2 path as argument
2. Validate both repositories
3. Add repo_2 as temporary local remote (`local-sync`)
4. Fetch updates from temporary remote
5. Show commit summary and ask for confirmation
6. Update main branch to match repo_2's main
7. Return to original branch
8. Clean up temporary remote

### Usage
```bash
./scripts/git-sync-local.sh /path/to/repo_2
./scripts/git-sync-local.sh /path/to/repo_2 --dry-run
./scripts/git-sync-local.sh /path/to/repo_2 --yes
```

## Safety & Validation

### Pre-sync Checks
- Verify repo_2 path exists and is a git repository
- Verify current directory is a git repository
- Verify main branch exists in both repos
- Store current branch to return to it later
- Warn if uncommitted changes on feature branch (but allow)
- Exit if on main branch with uncommitted changes (prevents data loss)

### Conflict Prevention
- If main has local commits not in repo_2: abort with error
- Suggest creating backup branch: `git branch backup-main-$(date +%Y%m%d)`
- Main branch should always be clean in this workflow

### Remote Name Collision
- Check if `local-sync` remote already exists
- Use alternative name if needed: `local-sync-temp-$$`
- Remove leftover remotes from failed runs

### Cleanup Guarantee
- Use bash `trap` to ensure temporary remote removal even on failure
- Prevents polluting remote list

## User Feedback

### Progress Reporting
```
[1/6] Validating repositories...
[2/6] Adding local-sync remote...
[3/6] Fetching updates from /path/to/repo_2...
[4/6] Checking for new commits...
[5/6] Updating main branch...
[6/6] Cleaning up...
```

### Commit Summary
Before updating, show what will change:
```
Found 3 new commits on main:
  c3939fb Merge pull request #1 from mm0809/gitblame-dev
  dc72491 Implement cursor sync
  56e35ac Refactor gitblame

Proceed with sync? [Y/n]
```

### Final Summary
```
✓ Successfully synced main branch
✓ Pulled 3 new commits
✓ Returned to branch: feature/my-work

Your main branch is now up to date with repo_2.
To update your current branch, run: git rebase main
```

## Implementation Details

### Key Git Commands
```bash
# Add temporary remote
git remote add local-sync "$REPO2_PATH"

# Fetch updates
git fetch local-sync

# Check for new commits
git log main..local-sync/main --oneline

# Update main (using reset since main should be clean)
git checkout main
git reset --hard local-sync/main

# Return to original branch
git checkout "$ORIGINAL_BRANCH"

# Cleanup with trap
trap 'git remote remove local-sync 2>/dev/null' EXIT
```

### Script Structure
- Function-based design for maintainability
- Functions: `validate_repo()`, `check_main_clean()`, `show_commits()`, `sync_main()`
- Color output using tput or ANSI codes
- Exit codes:
  - 0: Success
  - 1: Validation errors
  - 2: User cancellation

### Command-line Flags
- `--dry-run`: Show what would happen without making changes
- `--yes` or `-y`: Skip confirmation prompt

### Installation
```bash
chmod +x scripts/git-sync-local.sh
```

## Error Handling

### Exit Conditions
- Repo_2 path not provided or doesn't exist
- Repo_2 is not a git repository
- Current directory is not a git repository
- Main branch doesn't exist in either repo
- User on main branch with uncommitted changes
- Main branch has local commits (should be clean)

### Non-blocking Warnings
- Uncommitted changes on feature branch (warns but continues)

## Future Enhancements (Not Included)
- Auto-rebase current feature branch after sync
- Interactive branch selection for multiple rebases
- Configuration file for default repo_2 path
- Support for syncing other branches besides main
