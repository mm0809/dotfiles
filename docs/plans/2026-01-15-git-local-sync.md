# Git Local Sync Script Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a bash script that syncs the main branch from a local backup repository without network access.

**Architecture:** Function-based bash script with validation, temporary remote management, and interactive confirmation. Uses trap for cleanup guarantees.

**Tech Stack:** Bash, Git

---

## Task 1: Create Script Skeleton with Argument Parsing

**Files:**
- Create: `scripts/git-sync-local.sh`

**Step 1: Create basic script structure with shebang and argument parsing**

```bash
#!/bin/bash

set -e  # Exit on error

# Script to sync main branch from a local backup repository

REPO2_PATH=""
DRY_RUN=false
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --yes|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            if [[ -z "$REPO2_PATH" ]]; then
                REPO2_PATH="$1"
            else
                echo "Error: Unexpected argument '$1'"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if repo path provided
if [[ -z "$REPO2_PATH" ]]; then
    echo "Usage: $0 <repo2-path> [--dry-run] [--yes|-y]"
    echo ""
    echo "Sync main branch from a local backup repository"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would happen without making changes"
    echo "  --yes, -y    Skip confirmation prompt"
    exit 1
fi

echo "Git Local Sync"
echo "=============="
echo ""
```

**Step 2: Make script executable**

Run: `chmod +x scripts/git-sync-local.sh`

**Step 3: Test argument parsing**

Run: `./scripts/git-sync-local.sh`
Expected: Shows usage message and exits

Run: `./scripts/git-sync-local.sh /some/path`
Expected: Shows "Git Local Sync" header

Run: `./scripts/git-sync-local.sh /some/path --dry-run --yes`
Expected: Shows "Git Local Sync" header

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add git-sync-local script skeleton with argument parsing"
```

---

## Task 2: Add Color Output Helper Functions

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add color helper functions after the header**

Add after the "Git Local Sync" echo statements:

```bash
# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

step() {
    local current=$1
    local total=$2
    local message=$3
    echo -e "${BLUE}[$current/$total]${NC} $message"
}
```

**Step 2: Test color functions**

Add temporary test code before the exit at end of script:

```bash
info "This is info"
success "This is success"
warning "This is warning"
error "This is error"
step 1 6 "Testing step"
```

Run: `./scripts/git-sync-local.sh /tmp`
Expected: See colored output (blue, green, yellow, red, blue)

**Step 3: Remove test code**

Remove the temporary test lines added in step 2.

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add color output helpers for better readability"
```

---

## Task 3: Add Repository Validation Functions

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add validation functions before the argument parsing section**

Add after color helpers:

```bash
# Validation functions
validate_repo() {
    local repo_path=$1
    local repo_name=$2

    if [[ ! -d "$repo_path" ]]; then
        error "Directory does not exist: $repo_path"
        return 1
    fi

    if [[ ! -d "$repo_path/.git" ]]; then
        error "Not a git repository: $repo_path"
        return 1
    fi

    return 0
}

validate_branch_exists() {
    local repo_path=$1
    local branch=$2

    if [[ "$repo_path" == "." ]]; then
        # Current repo
        if ! git rev-parse --verify "$branch" &>/dev/null; then
            error "Branch '$branch' does not exist in current repository"
            return 1
        fi
    else
        # Remote repo
        if ! git -C "$repo_path" rev-parse --verify "$branch" &>/dev/null; then
            error "Branch '$branch' does not exist in $repo_path"
            return 1
        fi
    fi

    return 0
}
```

**Step 2: Add validation calls in main flow**

Add before the final echo statements:

```bash
# Step 1: Validate repositories
step 1 6 "Validating repositories..."

# Validate repo2
if ! validate_repo "$REPO2_PATH" "repo2"; then
    exit 1
fi

# Validate current repo
if ! validate_repo "." "current"; then
    exit 1
fi

# Validate main branch exists in both repos
if ! validate_branch_exists "." "main"; then
    exit 1
fi

if ! validate_branch_exists "$REPO2_PATH" "main"; then
    exit 1
fi

success "Both repositories validated"
echo ""
```

**Step 3: Test validation**

Run: `./scripts/git-sync-local.sh /nonexistent`
Expected: Error "Directory does not exist"

Run: `./scripts/git-sync-local.sh /tmp`
Expected: Error "Not a git repository"

Run in git repo: `./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles`
Expected: Success "Both repositories validated"

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add repository validation functions"
```

---

## Task 4: Add Safety Checks for Uncommitted Changes

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add function to check for uncommitted changes**

Add after validate_branch_exists function:

```bash
check_uncommitted_changes() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        if [[ "$current_branch" == "main" ]]; then
            error "You are on main branch with uncommitted changes"
            error "Please commit or stash your changes first"
            return 1
        else
            warning "You have uncommitted changes on branch '$current_branch'"
            warning "These changes will be preserved"
            echo ""
        fi
    fi

    return 0
}

check_main_clean() {
    # Check if main has local commits not in repo2
    local main_commit=$(git rev-parse main)
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Store original branch for later
    echo "$current_branch"
}
```

**Step 2: Add safety check call in main flow**

Add after repository validation:

```bash
# Step 2: Check for uncommitted changes
if ! check_uncommitted_changes; then
    exit 1
fi

ORIGINAL_BRANCH=$(check_main_clean)
```

**Step 3: Test uncommitted changes check**

Make a test change: `echo "test" >> test.txt`

Run on main branch: `./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles`
Expected: Error about uncommitted changes on main

Run on feature branch: `git checkout -b test-branch && ./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles`
Expected: Warning but continues

Clean up: `git checkout main && git branch -D test-branch && rm test.txt`

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add safety checks for uncommitted changes"
```

---

## Task 5: Add Remote Management with Cleanup Trap

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add remote management functions**

Add after check_main_clean function:

```bash
get_remote_name() {
    local base_name="local-sync"

    # Check if base name exists
    if ! git remote | grep -q "^${base_name}$"; then
        echo "$base_name"
        return 0
    fi

    # Use process ID suffix if collision
    echo "${base_name}-temp-$$"
}

cleanup_remote() {
    local remote_name=$1
    if git remote | grep -q "^${remote_name}$"; then
        git remote remove "$remote_name" 2>/dev/null || true
    fi
}

add_remote() {
    local remote_name=$1
    local repo_path=$2

    step 2 6 "Adding temporary remote '$remote_name'..."
    git remote add "$remote_name" "$repo_path"

    # Setup cleanup trap
    trap "cleanup_remote $remote_name" EXIT

    success "Remote added"
    echo ""
}

fetch_remote() {
    local remote_name=$1
    local repo_path=$2

    step 3 6 "Fetching updates from $repo_path..."
    if ! git fetch "$remote_name" 2>&1; then
        error "Failed to fetch from remote"
        return 1
    fi

    success "Fetch completed"
    echo ""
    return 0
}
```

**Step 2: Add remote operations in main flow**

Add after storing ORIGINAL_BRANCH:

```bash
# Get remote name (handle collisions)
REMOTE_NAME=$(get_remote_name)

if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would use remote name '$REMOTE_NAME'"
    info "DRY RUN: Would add remote for $REPO2_PATH"
    info "DRY RUN: Would fetch updates"
    echo ""
else
    # Add remote and fetch
    add_remote "$REMOTE_NAME" "$REPO2_PATH"
    if ! fetch_remote "$REMOTE_NAME" "$REPO2_PATH"; then
        exit 1
    fi
fi
```

**Step 3: Test remote operations**

Run with dry-run: `./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles --dry-run`
Expected: Shows "DRY RUN: Would add remote..." messages

Run actual fetch: `./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles`
Expected: Adds remote, fetches, then trap cleanup removes remote

Verify cleanup: `git remote`
Expected: No local-sync remote remains

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add remote management with cleanup trap"
```

---

## Task 6: Add Commit Summary Display

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add function to show commit differences**

Add after fetch_remote function:

```bash
show_commits() {
    local remote_name=$1

    step 4 6 "Checking for new commits..."

    # Get commit list
    local commits=$(git log --oneline main.."${remote_name}/main" 2>/dev/null)

    if [[ -z "$commits" ]]; then
        info "No new commits found. Main branch is already up to date."
        return 1
    fi

    local commit_count=$(echo "$commits" | wc -l)
    echo ""
    success "Found $commit_count new commit(s) on main:"
    echo "$commits" | while read -r line; do
        echo "  $line"
    done
    echo ""

    return 0
}
```

**Step 2: Add commit display in main flow**

Add after fetch operations:

```bash
# Show commits
if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would check for new commits"
    NEW_COMMITS=true
else
    if ! show_commits "$REMOTE_NAME"; then
        # No new commits, exit gracefully
        exit 0
    fi
    NEW_COMMITS=true
fi
```

**Step 3: Test commit summary**

Create test scenario with different commits:
```bash
# In repo_2, make a test commit
cd /tmp && git clone /home/zklin/workspace/dotfiles test-repo2
cd test-repo2
echo "test" > test.txt
git add test.txt
git commit -m "Test commit"
```

Run script: `./scripts/git-sync-local.sh /tmp/test-repo2`
Expected: Shows "Found 1 new commit(s) on main" with commit hash and message

Clean up: `rm -rf /tmp/test-repo2`

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add commit summary display"
```

---

## Task 7: Add Interactive Confirmation

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add confirmation function**

Add after show_commits function:

```bash
confirm_sync() {
    if [[ "$SKIP_CONFIRM" == true ]]; then
        return 0
    fi

    echo -n "Proceed with sync? [Y/n] "
    read -r response

    case "$response" in
        [nN][oO]|[nN])
            info "Sync cancelled by user"
            exit 2
            ;;
        *)
            return 0
            ;;
    esac
}
```

**Step 2: Add confirmation in main flow**

Add after showing commits:

```bash
# Ask for confirmation
if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would ask for confirmation"
else
    confirm_sync
fi
```

**Step 3: Test confirmation**

Run and answer 'n': `./scripts/git-sync-local.sh /tmp/test-repo2`
Expected: Shows "Sync cancelled by user" and exits with code 2

Run and answer 'y': `./scripts/git-sync-local.sh /tmp/test-repo2`
Expected: Continues past confirmation

Run with --yes flag: `./scripts/git-sync-local.sh /tmp/test-repo2 --yes`
Expected: Skips confirmation prompt

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add interactive confirmation prompt"
```

---

## Task 8: Add Main Branch Sync Logic

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add sync function**

Add after confirm_sync function:

```bash
sync_main() {
    local remote_name=$1
    local original_branch=$2

    step 5 6 "Updating main branch..."

    # Switch to main
    if ! git checkout main 2>&1; then
        error "Failed to checkout main branch"
        return 1
    fi

    # Check if main has local commits
    local local_only=$(git log "${remote_name}/main..main" --oneline 2>/dev/null)
    if [[ -n "$local_only" ]]; then
        error "Main branch has local commits not in repo2"
        error "Main should be kept clean in this workflow"
        echo ""
        info "Suggestion: Create a backup branch first:"
        info "  git branch backup-main-\$(date +%Y%m%d)"
        git checkout "$original_branch" 2>/dev/null
        return 1
    fi

    # Reset main to match repo2
    if ! git reset --hard "${remote_name}/main" 2>&1; then
        error "Failed to update main branch"
        git checkout "$original_branch" 2>/dev/null
        return 1
    fi

    success "Main branch updated"
    echo ""

    # Return to original branch
    if [[ "$original_branch" != "main" ]]; then
        if ! git checkout "$original_branch" 2>&1; then
            warning "Failed to return to branch '$original_branch'"
            warning "You are currently on main branch"
            return 0
        fi
    fi

    return 0
}
```

**Step 2: Add sync call in main flow**

Add after confirmation:

```bash
# Sync main branch
step 5 6 "Updating main branch..."
if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would checkout main branch"
    info "DRY RUN: Would check for local commits on main"
    info "DRY RUN: Would reset main to match $REMOTE_NAME/main"
    if [[ "$ORIGINAL_BRANCH" != "main" ]]; then
        info "DRY RUN: Would return to branch '$ORIGINAL_BRANCH'"
    fi
    echo ""
else
    if ! sync_main "$REMOTE_NAME" "$ORIGINAL_BRANCH"; then
        exit 1
    fi
fi
```

**Step 3: Test sync logic**

Setup test with actual commits:
```bash
# Create test repo2 with new commit
cd /tmp && git clone /home/zklin/workspace/dotfiles test-repo2
cd test-repo2
echo "test" > test.txt
git add test.txt
git commit -m "Test commit"
```

Run script: `cd /home/zklin/workspace/dotfiles && ./scripts/git-sync-local.sh /tmp/test-repo2 --yes`
Expected: Updates main branch with test commit

Verify: `git log main -1`
Expected: Shows "Test commit"

Test local commits check:
```bash
echo "local" > local.txt
git add local.txt
git commit -m "Local commit"
./scripts/git-sync-local.sh /tmp/test-repo2 --yes
```
Expected: Error "Main branch has local commits not in repo2"

Clean up: `git reset --hard HEAD~2 && rm -rf /tmp/test-repo2`

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add main branch sync logic with safety checks"
```

---

## Task 9: Add Final Summary and Cleanup

**Files:**
- Modify: `scripts/git-sync-local.sh`

**Step 1: Add summary function**

Add after sync_main function:

```bash
show_summary() {
    local commit_count=$1
    local original_branch=$2

    step 6 6 "Cleanup complete"
    echo ""
    echo "Summary"
    echo "======="
    success "Successfully synced main branch"
    success "Pulled $commit_count new commit(s)"

    if [[ "$original_branch" != "main" ]]; then
        success "Returned to branch: $original_branch"
        echo ""
        info "Your main branch is now up to date with repo2."
        info "To update your current branch, run: ${GREEN}git rebase main${NC}"
    else
        echo ""
        info "Your main branch is now up to date with repo2."
    fi
}
```

**Step 2: Calculate commit count and show summary**

Modify the section where NEW_COMMITS is set to store count:

```bash
# Show commits
if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would check for new commits"
    COMMIT_COUNT=0
else
    if ! show_commits "$REMOTE_NAME"; then
        # No new commits, exit gracefully
        exit 0
    fi
    # Count commits
    COMMIT_COUNT=$(git log --oneline main.."${REMOTE_NAME}/main" 2>/dev/null | wc -l)
fi
```

Add at the end of the script (after all operations):

```bash
# Show final summary
if [[ "$DRY_RUN" == true ]]; then
    step 6 6 "Cleanup"
    echo ""
    info "DRY RUN: Would remove temporary remote"
    info "DRY RUN: Completed successfully"
else
    show_summary "$COMMIT_COUNT" "$ORIGINAL_BRANCH"
fi
```

**Step 3: Test complete workflow**

Setup test:
```bash
cd /tmp && git clone /home/zklin/workspace/dotfiles test-repo2
cd test-repo2
echo "test1" > test1.txt && git add test1.txt && git commit -m "Test commit 1"
echo "test2" > test2.txt && git add test2.txt && git commit -m "Test commit 2"
```

Run full workflow: `cd /home/zklin/workspace/dotfiles && ./scripts/git-sync-local.sh /tmp/test-repo2 --yes`
Expected: Complete sync with summary showing 2 commits

Test dry-run: `./scripts/git-sync-local.sh /tmp/test-repo2 --dry-run`
Expected: Shows all "DRY RUN: Would..." messages without making changes

Clean up: `git reset --hard HEAD~2 && rm -rf /tmp/test-repo2`

**Step 4: Commit**

```bash
git add scripts/git-sync-local.sh
git commit -m "feat: add final summary and complete workflow"
```

---

## Task 10: Add Documentation and Final Testing

**Files:**
- Create: `docs/git-sync-local-usage.md`
- Modify: `scripts/git-sync-local.sh` (add header comments)

**Step 1: Add comprehensive header comments to script**

Add at the top of `scripts/git-sync-local.sh` after shebang:

```bash
#!/bin/bash
#
# git-sync-local.sh - Sync main branch from local backup repository
#
# Usage:
#   ./scripts/git-sync-local.sh <repo2-path> [options]
#
# Description:
#   Syncs the main branch from a local backup repository without network access.
#   Designed for feature branch workflow where main is kept clean.
#
# Options:
#   --dry-run    Show what would happen without making changes
#   --yes, -y    Skip confirmation prompt
#
# Safety:
#   - Validates both repositories before syncing
#   - Prevents data loss by checking for uncommitted changes on main
#   - Warns about uncommitted changes on feature branches
#   - Uses trap to guarantee cleanup of temporary remotes
#   - Shows commit summary before syncing
#
# Exit Codes:
#   0 - Success
#   1 - Validation error or sync failure
#   2 - User cancelled
#

set -e  # Exit on error
```

**Step 2: Create usage documentation**

```markdown
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
```

**Step 3: Test all error conditions systematically**

Run test suite:
```bash
# Test 1: No arguments
./scripts/git-sync-local.sh
# Expected: Usage message

# Test 2: Invalid path
./scripts/git-sync-local.sh /nonexistent
# Expected: Error "Directory does not exist"

# Test 3: Not a git repo
./scripts/git-sync-local.sh /tmp
# Expected: Error "Not a git repository"

# Test 4: Uncommitted changes on main
echo "test" > test.txt
git add test.txt
./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles
# Expected: Error about uncommitted changes on main
git reset HEAD test.txt && rm test.txt

# Test 5: Already up to date
./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles
# Expected: "No new commits found"

# Test 6: Successful sync with confirmation
# (Requires actual test-repo2 with new commits)

# Test 7: Successful sync with --yes
# (Requires actual test-repo2 with new commits)

# Test 8: Dry run
./scripts/git-sync-local.sh /home/zklin/workspace/dotfiles --dry-run
# Expected: All "DRY RUN: Would..." messages
```

**Step 4: Commit documentation**

```bash
git add scripts/git-sync-local.sh docs/git-sync-local-usage.md
git commit -m "docs: add comprehensive documentation for git-sync-local script"
```

---

## Task 11: Integration Testing and Final Validation

**Files:**
- All created files

**Step 1: Create end-to-end test scenario**

```bash
# Setup test environment
cd /tmp
git clone /home/zklin/workspace/dotfiles test-main
git clone /home/zklin/workspace/dotfiles test-backup

# Make commits in backup repo
cd test-backup
echo "feature1" > feature1.txt
git add feature1.txt
git commit -m "Add feature 1"
echo "feature2" > feature2.txt
git add feature2.txt
git commit -m "Add feature 2"

# Switch to feature branch in main repo
cd test-main
git checkout -b my-feature
echo "my-work" > my-work.txt
git add my-work.txt
git commit -m "My feature work"
```

**Step 2: Run sync and verify results**

```bash
cd test-main
/home/zklin/workspace/dotfiles/scripts/git-sync-local.sh /tmp/test-backup --yes

# Verify results
git log main -2 --oneline
# Expected: Shows "Add feature 2" and "Add feature 1"

git branch
# Expected: Shows "* my-feature" (returned to original branch)

git log my-feature -1 --oneline
# Expected: Shows "My feature work" (unchanged)
```

**Step 3: Test rebase suggestion**

```bash
cd test-main
git rebase main
# Expected: my-feature now based on updated main

git log --oneline --graph --all -10
# Expected: Shows clean history with my-feature on top of new main commits
```

**Step 4: Cleanup and final commit**

```bash
# Cleanup test repos
rm -rf /tmp/test-main /tmp/test-backup

# Final check in original repo
cd /home/zklin/workspace/dotfiles
./scripts/git-sync-local.sh --help 2>&1 | head -5
# Expected: Shows usage information
```

```bash
git add -A
git commit -m "test: validate git-sync-local end-to-end workflow

Completed integration testing with:
- Repository validation
- Commit syncing
- Branch switching
- Error handling
- Dry run mode
- Confirmation prompts

All tests passing. Script ready for production use."
```

---

## Completion Checklist

- [ ] Script handles argument parsing correctly
- [ ] Color output makes feedback clear and readable
- [ ] Repository validation prevents invalid operations
- [ ] Safety checks protect against data loss
- [ ] Remote management with guaranteed cleanup
- [ ] Commit summary shows what will change
- [ ] Interactive confirmation (skippable with --yes)
- [ ] Main branch sync with local commit detection
- [ ] Returns to original branch after sync
- [ ] Final summary shows clear results
- [ ] Comprehensive documentation
- [ ] All error conditions tested
- [ ] End-to-end workflow validated
- [ ] Script is executable
- [ ] Dry-run mode works correctly

---

## Notes

- Script assumes `main` as the primary branch name
- Uses `set -e` for fail-fast behavior
- Trap ensures cleanup even on errors
- All user-facing output uses color helpers
- Exit codes follow Unix conventions
- Documentation covers common troubleshooting scenarios
