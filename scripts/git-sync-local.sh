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

set -eu  # Exit on error and unset variables

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
                echo "Error: Unexpected argument '$1'" >&2
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

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}${1}${NC}"
}

success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

error() {
    echo -e "${RED}✗ ${1}${NC}" >&2
}

step() {
    local current="${1}"
    local total="${2}"
    local message="${3}"
    echo -e "${BLUE}[$current/$total]${NC} $message"
}

# Validation functions
validate_repo() {
    local repo_path=$1
    local repo_name=$2

    if [[ ! -d "$repo_path" ]]; then
        error "Directory does not exist for $repo_name: $repo_path"
        return 1
    fi

    if [[ ! -d "$repo_path/.git" ]]; then
        error "Not a git repository for $repo_name: $repo_path"
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

check_uncommitted_changes() {
    local current_branch="$(git rev-parse --abbrev-ref HEAD)"

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
    local main_commit="$(git rev-parse main)"
    local current_branch="$(git rev-parse --abbrev-ref HEAD)"

    # Store original branch for later
    echo "$current_branch"
}

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

# Step 2: Check for uncommitted changes
if ! check_uncommitted_changes; then
    exit 1
fi

ORIGINAL_BRANCH=$(check_main_clean)

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

# Ask for confirmation
if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would ask for confirmation"
else
    confirm_sync
fi

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

# Show final summary
if [[ "$DRY_RUN" == true ]]; then
    step 6 6 "Cleanup"
    echo ""
    info "DRY RUN: Would remove temporary remote"
    info "DRY RUN: Completed successfully"
else
    show_summary "$COMMIT_COUNT" "$ORIGINAL_BRANCH"
fi
