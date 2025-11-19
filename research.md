# Research on vim/ Folder

## Overview
The `vim/` folder in this dotfiles repository contains configuration files and plugins for both Vim and Neovim text editors. It is organized into two main subdirectories: `nvim/` for Neovim-specific Lua-based configurations, and `site/` for Vim packages installed via the built-in package system.

## Directory Structure

### nvim/
This directory holds Neovim configuration files written in Lua, reflecting the modern approach to Neovim configuration.

#### init.lua
- **Purpose**: Main initialization file for Neovim
- **Key Features**:
  - Sets the path to clangd LSP binary (`/home/zklin/program/clangd_20.1.8/bin/clangd`)
  - Loads configuration modules: `options`, `lsp`, and `plugins`
  - Sets the color scheme to `gruvbox`
  - Defines key mappings:
    - `jj` in insert mode to escape
    - `gl` in normal mode to open floating diagnostics

#### lua/options.lua
- **Purpose**: General Vim/Neovim options configuration
- **Settings**:
  - Line numbers and relative line numbers enabled
  - Tab settings: expand tabs to spaces, 4-space width
  - Cursor line highlighting
  - Disabled clipboard integration (commented out)
  - Scroll offset of 999 (keeps cursor centered)
  - Virtual edit in block mode
  - Incremental command with split preview
  - True color support enabled
  - Completion menu options with fuzzy matching

#### lua/lsp.lua
- **Purpose**: Language Server Protocol (LSP) configuration for code intelligence
- **Configured Servers**:
  - **clangd**: For C/C++ development
    - Uses custom clangd binary path
    - Filetypes: cpp, c, inc
    - Root markers: compile_commands.json, .git
  - **pyright**: For Python development
    - Filetypes: python
    - Root markers: requirements.txt, setup.py, .git
    - Analysis settings for library code types and open-files-only diagnostics
- **Key Bindings** (attached on LSP buffer):
  - `K`: Hover documentation
  - `gd`: Go to definition
  - `gD`: Go to declaration
  - `gi`: Go to implementation
  - `gt`: Go to type definition
  - `gr`: Find references
  - `Ctrl+Space`: Trigger completion (insert mode)
  - `Ctrl+k`: Signature help (insert mode)
- **Completion Features**:
  - Tab-based completion with intelligent source selection
  - LSP omnifunc integration
  - Custom tab completion logic for different contexts
- **Diagnostic Settings**:
  - Virtual text disabled
  - No diagnostics update in insert mode

#### lua/plugins.lua
- **Purpose**: Plugin management using lazy.nvim
- **Features**:
  - Bootstrap lazy.nvim if not present
  - Configures kanagawa color scheme with custom styling:
    - Bold keywords and statements
    - No italic keywords
- **Note**: Despite configuring kanagawa, the init.lua sets gruvbox as the active colorscheme

### site/
This directory contains Vim packages installed via the built-in `pack/` system, located at `site/pack/default/start/`.

#### fzf/
- **Purpose**: Fuzzy finder plugin for Vim
- **Features**:
  - Command-line fuzzy finder integration
  - `:FZF` command for file searching
  - Core functions: `fzf#run()` and `fzf#wrap()`
  - Customizable layouts, colors, and key bindings
  - History support
  - Multi-select capabilities
  - Integration with Vim commands for opening files
- **Key Capabilities**:
  - File and directory fuzzy searching
  - Custom source commands
  - Popup window support (Vim 8+/Neovim)
  - Tmux integration
  - Color scheme matching

#### gruvbox.nvim/
- **Purpose**: Neovim port of the popular gruvbox color scheme
- **Features**:
  - Lua-based implementation
  - Treesitter syntax highlighting support
  - LSP semantic highlighting support
  - Multiple contrast options (hard, soft, normal)
  - Customizable palette overrides
  - Highlight group overrides
  - Terminal color support
  - Support for italics, bold, underline, strikethrough
  - Transparent mode option
  - Dim inactive windows

## Usage and Integration
- The Neovim configuration uses Lua modules for better organization and performance
- LSP setup provides intelligent code completion and navigation for C/C++ and Python
- fzf enables efficient file and content searching within Vim
- gruvbox provides a consistent, eye-friendly color scheme
- The setup appears optimized for development workflows involving multiple programming languages

## Notes
- The configuration includes a custom clangd binary path, suggesting specialized C/C++ development setup
- Despite lazy.nvim configuring kanagawa theme, gruvbox is the active colorscheme
- All components work together to create a comprehensive Vim/Neovim development environment