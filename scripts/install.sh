#!/usr/bin/env bash

set -e

MY_DOTFILES_ROOT=$(git rev-parse --show-toplevel)

DRY_RUN=0

RED='\033[0;31m'
BLU='\033[0;34m'
NC='\033[0m'

execute() {
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        "$@"
    else
        echo -e "${BLU}[DRY RUN]${NC} $@"
    fi
}

# create a symbol link
# if there is a file exist backup the file
create_symlink() {
    local file=$1
    local link=$2


    echo -e "Create link for: ${link}"

    # if is a symlink, delete the link
    # otherwise, make a backup
    if [[ -e "$link" ]]; then
        if [[ -L "$link" ]]; then
            echo -e "${RED}Remove${NC} old link at ${link}"
            execute rm "${link}"
        else
            echo -e "${BLU}Backup${NC} ${link} at ${link}.backup"
            execute "${link}" "${link}.backup"
        fi
    fi

    echo "Add symbol link from ${link} to ${file}"
    execute ln -s "${file}" "${link}"
}

while (( "$#" )); do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "${RED}Error: Unsupported arguments.${NC}"
            exit 1
            ;;
    esac
done

# Setup for neovim
mkdir -p ~/.config
mkdir -p ~/.local/share/nvim
create_symlink ${MY_DOTFILES_ROOT}/vim/nvim ~/.config/nvim
create_symlink ${MY_DOTFILES_ROOT}/vim/site ~/.local/share/nvim/site

# Setup for tmux
create_symlink ${MY_DOTFILES_ROOT}/tmux/tmux.conf ~/.tmux.conf
