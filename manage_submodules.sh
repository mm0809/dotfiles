#!/bin/bash

# manage_submodules.sh
# A script to manage Git submodules in the vim/site/pack/default/start directory

set -e  # Exit on error

# Constants
SUBMODULE_DIR="vim/site/pack/default/start"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warning() {
    echo -e "${YELLOW}$1${NC}"
}

confirm() {
    local prompt="$1"
    local response
    read -p "$prompt (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error_exit "Not in a git repository. Please run this script from the repository root."
    fi
}

# Check if .gitmodules exists (for operations that need it)
check_gitmodules() {
    if [ ! -f ".gitmodules" ]; then
        warning ".gitmodules file not found."
        return 1
    fi
    return 0
}

# Extract repository name from URL
get_repo_name() {
    local url="$1"
    local name
    # Remove .git suffix if present and get basename
    name=$(basename "$url" .git)
    echo "$name"
}

# List all submodules
list_submodules() {
    echo "Submodules:"
    
    if ! check_gitmodules || [ ! -s ".gitmodules" ]; then
        echo "No submodules found."
        return
    fi
    
    git submodule status | while read -r line; do
        # Parse the status line
        local commit_hash=$(echo "$line" | awk '{print $1}' | sed 's/^[+-]//') 
        local path=$(echo "$line" | awk '{print $2}')
        local name=$(basename "$path")
        
        # Get the URL
        local url=$(git config --get "submodule.$path.url" 2>/dev/null || echo "N/A")
        
        echo "- $name ($path) [$commit_hash] $url"
    done
}

# Add a new submodule
add_submodule() {
    local url="$1"
    local name="$2"
    
    if [ -z "$url" ]; then
        error_exit "URL is required for adding a submodule. Usage: $0 --add <url> [name]"
    fi
    
    # If name is not provided, extract from URL
    if [ -z "$name" ]; then
        name=$(get_repo_name "$url")
    fi
    
    local path="$SUBMODULE_DIR/$name"
    
    # Check if submodule already exists
    if [ -d "$path" ]; then
        error_exit "Submodule directory '$path' already exists."
    fi
    
    echo "Adding submodule '$name'..."
    
    if git submodule add "$url" "$path"; then
        success "Submodule '$name' added successfully."
    else
        error_exit "Failed to add submodule '$name'."
    fi
}

# Update all submodules
update_submodules() {
    echo "Updating submodules..."
    
    if ! check_gitmodules || [ ! -s ".gitmodules" ]; then
        echo "No submodules to update."
        return
    fi
    
    # Get list of submodule paths
    local submodules=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')
    
    if [ -z "$submodules" ]; then
        echo "No submodules to update."
        return
    fi
    
    for path in $submodules; do
        local name=$(basename "$path")
        echo -n "Updating $name... "
        if git submodule update --remote "$path" > /dev/null 2>&1; then
            echo "Done."
        else
            warning "Failed to update $name."
        fi
    done
    
    success "All submodules updated successfully."
}

# Remove a submodule
remove_submodule() {
    local name="$1"
    
    if [ -z "$name" ]; then
        error_exit "Submodule name is required for removal. Usage: $0 --remove <name>"
    fi
    
    local path="$SUBMODULE_DIR/$name"
    
    # Check if submodule exists
    if [ ! -d "$path" ]; then
        error_exit "Submodule '$name' not found at path '$path'."
    fi
    
    # Confirm removal
    if ! confirm "Are you sure you want to remove submodule '$name'?"; then
        echo "Removal cancelled."
        return
    fi
    
    echo "Removing submodule '$name'..."
    
    # Deinitialize the submodule
    if ! git submodule deinit -f "$path" 2>/dev/null; then
        warning "Failed to deinitialize submodule. Continuing..."
    fi
    
    # Remove from git
    if ! git rm -f "$path" 2>/dev/null; then
        error_exit "Failed to remove submodule from git."
    fi
    
    # Remove from .git/modules
    if [ -d ".git/modules/$path" ]; then
        rm -rf ".git/modules/$path"
    fi
    
    success "Submodule '$name' removed successfully."
}

# Show status of submodules
status_submodules() {
    echo "Submodule status:"
    
    if ! check_gitmodules || [ ! -s ".gitmodules" ]; then
        echo "No submodules found."
        return
    fi
    
    git submodule status
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [OPTION]

Manage Git submodules in the $SUBMODULE_DIR directory.

Options:
  --list                  List all current submodules with paths, URLs, and commits
  --add <url> [name]      Add a new submodule from the given URL
                          If name is not provided, it will be extracted from the URL
  --update                Update all submodules to the latest commits on tracked branches
  --remove <name>         Remove a submodule by name (prompts for confirmation)
  --status                Show the status of all submodules
  --help                  Display this help message

Examples:
  $0 --list
  $0 --add https://github.com/user/plugin.git
  $0 --add https://github.com/user/plugin.git my-plugin
  $0 --update
  $0 --remove my-plugin
  $0 --status

Note: This script must be run from the repository root directory.

EOF
}

# Main script execution
main() {
    # Check if running from git repository
    check_git_repo
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        --list)
            list_submodules
            ;;
        --add)
            shift
            add_submodule "$@"
            ;;
        --update)
            update_submodules
            ;;
        --remove)
            shift
            remove_submodule "$@"
            ;;
        --status)
            status_submodules
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"