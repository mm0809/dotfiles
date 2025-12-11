#!/usr/bin/env bash
mkdir -p downloads

#fzf
wget -P downloads/ https://github.com/junegunn/fzf/releases/download/v0.65.2/fzf-0.65.2-linux_amd64.tar.gz

#neovim
wget -P downloads/ https://github.com/neovim/neovim/releases/download/v0.11.4/nvim-linux-x86_64.tar.gz

#lazygit
wget -P downloads/ https://github.com/jesseduffield/lazygit/releases/download/v0.55.1/lazygit_0.55.1_linux_x86_64.tar.gz

#gtag
wget -P downloads/ https://mirror.ossplanet.net/gnu/global/global-6.6.14.tar.gz

#ripgrep
wget -P downloads/ https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-unknown-linux-musl.tar.gz

# Don't download clangd in default
# wget -P downloads/ https://github.com/clangd/clangd/releases/download/20.1.8/clangd-linux-20.1.8.zip
