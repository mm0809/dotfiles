# Git Local Sync Usage Guide

## Overview

`git-sync-local.sh` syncs your main branch from a local backup repository without requiring network access.

## Prerequisites

- Working in a git repository
- Have a backup/mirror repository accessible on local filesystem
- Using feature branch workflow (main branch kept clean)

## Basic Usage

### Simple sync
```bash
./scripts/git-sync-local.sh /path/to/backup-repo
```

### Skip confirmation
```bash
./scripts/git-sync-local.sh /path/to/backup-repo --yes
```

### Preview changes (dry run)
```bash
./scripts/git-sync-local.sh /path/to/backup-repo --dry-run
```

## Workflow

1. Script validates both repositories
2. Checks for uncommitted changes (errors if on main with changes)
3. Adds temporary remote pointing to backup repo
4. Fetches updates
5. Shows commit summary
6. Asks for confirmation (unless --yes flag used)
7. Updates main branch
8. Returns to original branch
9. Cleans up temporary remote

## Safety Features

- **Uncommitted changes on main**: Script exits with error
- **Uncommitted changes on feature branch**: Warning shown but continues
- **Local commits on main**: Script exits (main should be clean)
- **Automatic cleanup**: Temporary remote always removed via trap

## After Syncing

If you were on a feature branch, update it with:
```bash
git rebase main
```

## Exit Codes

- `0`: Success
- `1`: Validation error or sync failure
- `2`: User cancelled at confirmation prompt

## Troubleshooting

### "Main branch has local commits"
Main should be kept clean in this workflow. Create a backup branch:
```bash
git branch backup-main-$(date +%Y%m%d)
git reset --hard origin/main  # or manually resolve
```

### "Not a git repository"
Ensure both current directory and backup path are git repositories.

### Remote name collision
Script automatically handles this by using `local-sync-temp-$$` if needed.
