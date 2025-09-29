#!/usr/bin/env bash

MY_DOTFILES_ROOT=$(realpath $(dirname $0))

# create a symbol link
# if there is a file exist backup the file
create_symlink() {
    file=$1
    link=$2

    if [[ -e "$link" ]]; then
        mv $link ${link}.backup
    fi

    ln -s $file $link
}

# Setup for neovim
mkdir -p ~/.config
mkdir -p ~/.local/share/nvim
create_symlink ${MY_DOTFILES_ROOT}/vim/nvim ~/.config/nvim
create_symlink ${MY_DOTFILES_ROOT}/vim/site ~/.local/share/nvim/site

# Setup for tmux
create_symlink ${MY_DOTFILES_ROOT}/tmux/tmux.conf ~/.tmux.conf
