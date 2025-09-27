#!/usr/bin/env bash

MY_DOTFILES_ROOT=$(realpath $(dirname $0))

mkdir -p ~/.config
mkdir -p ~/.local/share/nvim
ln -s ${MY_DOTFILES_ROOT}/vim/nvim ~/.config/nvim
ln -s ${MY_DOTFILES_ROOT}/vim/site ~/.local/share/nvim/site

