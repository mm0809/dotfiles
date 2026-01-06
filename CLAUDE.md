# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal Linux dotfiles repository managing Neovim, tmux, and development tool configurations. Uses symlink-based installation with git submodules for vim plugins.

## Essential Commands

### Installation and Setup
```bash
# Install dotfiles (creates symlinks to ~/.config and ~/)
./scripts/install.sh

# Download development tools (fzf, neovim, lazygit, ripgrep, gtag)
./scripts/download.sh
```

### Plugin Management
```bash
# List all vim plugin submodules
./scripts/manage_submodules.sh --list

# Add a new vim plugin
./scripts/manage_submodules.sh --add <url> [name]

# Update all submodules to latest
./scripts/manage_submodules.sh --update

# Remove a plugin (with confirmation)
./scripts/manage_submodules.sh --remove <name>
```

### Testing Configuration
```bash
# Test Neovim configuration for errors
nvim --headless -c "checkhealth" -c "quit"

# Validate LSP setup
nvim --headless -c "checkhealth lsp" -c "quit"

# Check if LSP servers are available
which clangd pyright lua-language-server
```

## Architecture Overview

### Dual Plugin Management System

The repository uses **two distinct plugin management approaches**:

1. **Git Submodules** (`vim/site/pack/default/start/`)
   - Managed via `./scripts/manage_submodules.sh`
   - Automatically loaded by Neovim's native package system
   - Used for: stable plugins, colorschemes, rarely-changing tools
   - Current plugins: gruvbox.nvim, tokyonight.nvim, fzf, fzf.vim

2. **lazy.nvim** (`vim/nvim/lua/plugins.lua`)
   - Auto-bootstraps on first Neovim launch
   - Used for: plugins requiring configuration, lazy loading, frequent updates
   - Current plugins: kanagawa.nvim

When adding new plugins, prefer submodules for simplicity unless lazy loading or complex configuration is needed.

### Configuration Structure

**Neovim configuration** (`vim/nvim/`):
- `init.lua` - Main entry point, sets leader key, loads all modules
- `lua/options.lua` - Editor settings (indentation, UI, completion)
- `lua/lsp.lua` - LSP configuration for clangd, pyright, lua_ls
- `lua/plugins.lua` - lazy.nvim plugin setup
- `lua/gitblame/` - Custom git blame plugin (926 lines, split window viewer)

**Symlink targets** (created by `install.sh`):
- `vim/nvim` → `~/.config/nvim`
- `vim/site` → `~/.local/share/nvim/site`
- `tmux/tmux.conf` → `~/.tmux.conf`

### LSP Configuration Details

Three language servers configured in `vim/nvim/lua/lsp.lua`:

1. **clangd** (C/C++)
   - Path: Set via `clangd_path` variable in `init.lua`
   - Root markers: `compile_commands.json`, `.git`
   - Filetypes: cpp, c, inc

2. **pyright** (Python)
   - Root markers: `requirements.txt`, `setup.py`, `.git`
   - Settings: auto-search paths, use library code types

3. **lua_ls** (Lua)
   - Custom `on_init` for Neovim integration
   - Includes Neovim runtime files in library path
   - LuaJIT version detection

LSP keybindings are set on `LspAttach` autocmd. See `lua/lsp.lua` for full list.

### Custom Gitblame Plugin

Located in `vim/nvim/lua/gitblame/`, this is a custom-built plugin with:
- **Main implementation**: `back.lua` (705 lines) - configuration and core logic
- **Command setup**: `init.lua` (150 lines) - plugin initialization
- **UI utilities**: `ui.lua` (35 lines) - buffer/window management
- **Logging**: `util.lua` (36 lines) - debug utilities

**Usage**: Press `<leader>gb` to open git blame in left split. Press `-` in blame window to show blame before current commit.

**Reload during development**: `<leader>rr` reloads the plugin without restarting Neovim.

## Code Style

### Lua (Neovim Configuration)
- 4 spaces indentation (no tabs)
- `snake_case` for variables/functions
- Module pattern: `local M = {}` ... `return M`
- Error handling: Use `vim.notify()` with appropriate log levels
- Keep line length under ~100 chars

### Shell Scripts
- Start with `#!/usr/bin/env bash` and `set -e`
- Define color constants at top (RED, GREEN, YELLOW, NC)
- Use `error_exit()` pattern for errors
- Use `confirm()` pattern for user confirmations
- `snake_case` for functions and variables

## Git Workflow

### Commit Message Style
Use imperative mood:
- Good: "Add feature", "Update config", "Fix bug"
- Bad: "Added feature", "Fixing bug", "Updates"

### Working with Submodules
```bash
# After adding/updating submodules
git add .gitmodules vim/site/pack/default/start/<plugin>
git commit -m "Add <plugin> vim plugin"

# After pulling changes with submodule updates
git submodule update --init --recursive
```

## Development Notes

### Modifying Neovim Configuration
1. Edit files in `vim/nvim/lua/`
2. Reload without restarting: `<leader>rr` (for gitblame plugin)
3. Or manually: `:source ~/.config/nvim/init.lua`
4. Validate: `:checkhealth`

### Testing LSP Changes
1. Edit `vim/nvim/lua/lsp.lua`
2. Restart Neovim
3. Open a file of target language
4. Check `:LspInfo` to verify server attached
5. Test keybindings: `K` (hover), `gd` (definition), `gr` (references)

### Key Neovim Keybindings
- Leader key: `<Space>`
- `<leader>gb` - Git blame split window
- `<leader>rr` - Reload gitblame plugin
- `Ctrl-P` - FZF file search
- `jj` - Escape (insert mode)
- `gl` - Show diagnostic float
- LSP: `K`, `gd`, `gD`, `gi`, `gt`, `gr` (see lsp.lua)

## Important Paths
- Main config: `vim/nvim/init.lua`
- LSP config: `vim/nvim/lua/lsp.lua`
- Gitblame plugin: `vim/nvim/lua/gitblame/`
- Scripts: `scripts/` (install, manage_submodules, download, package)
- Submodules: `vim/site/pack/default/start/`
