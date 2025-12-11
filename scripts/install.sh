#!/usr/bin/env bash

MY_DOTFILES_ROOT=$(realpath $(dirname $0))

# create a symbol link
# if there is a file exist backup the file
create_symlink() {
    file=$1
    link=$2

    RED='\033[0;31m'
    BLU='\033[0;34m'
    NC='\033[0m'

    echo -e "Create link for: ${link}"

    # if is a symlink, delete the link
    # otherwise, make a backup
    if [[ -e "$link" ]]; then
        if [[ -L "$link" ]]; then
            rm $link
            echo -e "  ${RED}Remove${NC} old link at ${link}"
        else
            mv $link ${link}.backup
            echo -e "  ${BLU}Backup${NC} ${link} at ${link}.backup"
        fi
    fi

    ln -s $file $link
    echo "  Add symbol link from ${file} to ${link}"
}

# Setup for neovim
mkdir -p ~/.config
mkdir -p ~/.local/share/nvim
create_symlink ${MY_DOTFILES_ROOT}/vim/nvim ~/.config/nvim
create_symlink ${MY_DOTFILES_ROOT}/vim/site ~/.local/share/nvim/site

# Setup for tmux
create_symlink ${MY_DOTFILES_ROOT}/tmux/tmux.conf ~/.tmux.conf
