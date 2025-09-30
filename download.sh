#!/usr/bin/env bash
mkdir -p downloads

wget -P downloads/ https://github.com/junegunn/fzf/releases/download/v0.65.2/fzf-0.65.2-linux_amd64.tar.gz
wget -P downloads/ https://github.com/neovim/neovim/releases/download/v0.11.4/nvim-linux-x86_64.tar.gz
wget -P downloads/ https://mirror.ossplanet.net/gnu/global/global-6.6.14.tar.gz

# Don't download clangd in default
# wget -P downloads/ https://github.com/clangd/clangd/releases/download/20.1.8/clangd-linux-20.1.8.zip
