# CLAUDE.md - Gitblame Plugin

This file provides guidance to Claude Code when working with the custom Neovim git blame plugin.

## Overview

A custom Neovim plugin that displays git blame information in a split window with time-travel capabilities (viewing blame history before specific commits).

**Location**: `vim/nvim/lua/gitblame/`

**Total size**: ~221 lines across 3 files

**Main Features**:
- Split window git blame viewer (left side)
- Press `-` in blame window to show blame **before** a commit (time-travel)
- Async git operations (non-blocking UI)
- Simple, modular architecture

## File Structure

### init.lua (150 lines)
**Purpose**: Main plugin implementation and entry point

**Key Components**:
- **State** (lines 8-14):
  ```lua
  {
      filepath = nil,      -- Current file path
      source_buf = nil,    -- Original buffer number
      source_win = nil,    -- Original window ID
      blame_buf = nil,     -- Blame buffer number
      blame_win = nil      -- Blame window ID
  }
  ```

- **Configuration** (lines 16-18):
  ```lua
  {
      git_blame_args = {'--date=short'}  -- Git blame flags
  }
  ```

- **Main Functions**:
  - `git_blame()` (lines 124-138): Main entry point, orchestrates the blame flow
  - `show_blame(hash)` (lines 53-84): Runs git blame command asynchronously
  - `show_blame_before()` (lines 96-106): Time-travel to parent commit
  - `create_blame_buffer()` (lines 108-122): Creates blame buffer with keymaps
  - `open_blame_window()` (lines 42-51): Opens left vertical split
  - `setup()` (lines 140-148): Plugin initialization

**Workflow** (git_blame function):
1. `init()`: Validate file, capture source buffer/window
2. `create_blame_buffer()`: Create scratch buffer with keymaps
3. `open_blame_window()`: Open left vsplit
4. `show_blame()`: Run git blame and display results

**Time-Travel Feature** (show_blame_before):
1. Extract commit hash from current blame line
2. Pass hash to `show_blame(hash)` which runs `git blame <hash>^ -- <file>`
3. Display blame output from parent commit

### ui.lua (35 lines)
**Purpose**: UI utility functions for buffer and window management

**Functions**:
- `create_buffer(buftype, filetype, name)` (lines 7-23):
  - Creates scratch buffer with standard options
  - Sets buftype='nofile', bufhidden='wipe', swapfile=false, modifiable=false
  - Optionally sets filetype and buffer name
  - **Returns**: buffer number

- `render_buffer(bufnr, lines)` (lines 25-33):
  - Safely updates buffer content
  - Temporarily toggles modifiable on/off
  - Replaces all lines with provided content
  - Handles invalid buffers gracefully

**Scratch Buffer Settings**:
- `buftype=nofile`: Not associated with a file
- `bufhidden=wipe`: Auto-cleanup when hidden
- `swapfile=false`: No swap file creation
- `modifiable=false`: Read-only by default

### util.lua (36 lines)
**Purpose**: Logging and string manipulation utilities

**Functions**:
- `enable_log()` (lines 5-7): Enable debug logging
- `disable_log()` (lines 9-11): Disable debug logging
- `log(msg, data)` (lines 13-23):
  - Logs debug messages via `vim.notify`
  - Only logs when DEBUG is enabled
  - Supports optional data parameter (uses `vim.inspect`)
  - Log level: `vim.log.levels.DEBUG`

- `str_to_table(str)` (lines 25-34):
  - Splits string by newlines
  - Removes trailing empty line if present
  - Used to convert `vim.system` stdout to line array

**Debug Mode**: Enabled by calling `util.enable_log()` (currently enabled on line 4 of init.lua)

## Architecture

### Module Loading
When you `require('gitblame')`, Neovim loads `init.lua` by default (standard Lua behavior).

### Data Flow

```
User triggers <leader>gb
    ↓
git_blame() orchestrates workflow
    ↓
init() validates file and git availability
    ↓
create_blame_buffer() creates scratch buffer
    ↓
open_blame_window() creates left vsplit
    ↓
show_blame() spawns async git job
    ↓
on_exit callback renders output via ui.render_buffer()
```

### Time-Travel Flow

```
User presses '-' on a blame line
    ↓
show_blame_before() extracts commit hash
    ↓
get_commit_hash() parses hash from line start
    ↓
show_blame(hash) runs 'git blame <hash>^'
    ↓
Blame window shows parent commit's blame
```

## Key Implementation Details

### Async Git Execution
Uses `vim.system()` (line 83) introduced in Neovim 0.10+:
```lua
vim.system(cmd, {cwd = cwd, text = true}, on_exit)
```

**Advantages**:
- Non-blocking UI (async by default)
- Returns stdout/stderr as text
- Callback scheduled automatically

**Exit Handler**:
```lua
local on_exit = function(obj)
    vim.schedule(function()
        if obj.code == 0 then
            lines = util.str_to_table(obj.stdout)
        else
            lines = util.str_to_table(obj.stderr)
        end
        ui.render_buffer(state.blame_buf, lines)
    end)
end
```

### Commit Hash Extraction
Function: `get_commit_hash(line)` (lines 86-94)

Git blame format:
```
<commit_hash> (author date time line_num) content
```

Extraction pattern:
```lua
local hash = line:match('^(%x+)')  -- Match hex digits at start
```

Returns `nil` for invalid lines (empty or non-blame lines).

### Split Window Creation
Function: `open_blame_window(buf)` (lines 42-51)

```lua
vim.cmd('leftabove vsplit')  -- Open left vertical split
```

Window settings:
- No line numbers (`number = false`)
- No relative line numbers (`relativenumber = false`)
- No line wrapping (`wrap = false`)

### Scratch Buffer Pattern
Created via `ui.create_buffer('nofile', 'gitblame', 'gitblame://output')`:

**Why this pattern**:
- **nofile**: Buffer not tied to filesystem
- **wipe**: Auto-cleanup on hide (no buffer clutter)
- **no swapfile**: Temporary content doesn't need recovery
- **non-modifiable**: User shouldn't edit blame output

## Configuration

### Git Blame Arguments
Edit `config.git_blame_args` in init.lua (line 17):

```lua
git_blame_args = {'--date=short'}     -- Default (short date)
git_blame_args = {'--date=iso'}       -- ISO 8601 format
git_blame_args = {'--date=relative'}  -- "2 weeks ago"
git_blame_args = {'-w'}               -- Ignore whitespace changes
git_blame_args = {'--date=short', '-w'}  -- Multiple flags
```

Common flags:
- `--date=<format>`: Date format (short, iso, relative, human, unix)
- `-w`: Ignore whitespace changes
- `-M`: Detect moved lines
- `-C`: Detect copied lines

### Debug Logging
Enable/disable in init.lua (line 4):

```lua
util.enable_log()   -- Enable debug logs
util.disable_log()  -- Disable debug logs
```

Debug logs appear via `vim.notify` with DEBUG level.

## Keybindings

### Global (after setup)
- `<leader>gb`: Open git blame split

### In Blame Buffer
- `-`: Show blame **before** current commit (time-travel)

## Commands

- `:Gitblame`: Open git blame split for current file

## Setup

In your Neovim config (typically `init.lua`):

```lua
require('gitblame').setup()
```

This creates:
1. `:Gitblame` user command
2. `<leader>gb` keymap to trigger blame

## Development

### Hot Reload
Add to main init.lua for development:

```lua
vim.keymap.set('n', '<leader>rr', function()
    -- Clear module cache
    package.loaded['gitblame'] = nil
    package.loaded['gitblame.ui'] = nil
    package.loaded['gitblame.util'] = nil

    -- Reload
    require('gitblame').setup()
    vim.notify('Gitblame plugin reloaded', vim.log.levels.INFO)
end, { desc = 'Reload gitblame plugin' })
```

### Testing

**Test basic blame**:
1. Open a file in a git repository: `nvim <file>`
2. Press `<leader>gb`
3. Verify left split shows blame output

**Test time-travel**:
1. In blame window, position cursor on any line
2. Press `-`
3. Verify blame updates to show parent commit's blame
4. Press `-` multiple times to go back in history
5. Note: Source file doesn't change (unlike some implementations)

**Test error handling**:
1. Open non-git file: `nvim /tmp/test.txt`
2. Press `<leader>gb`
3. Verify error message appears

**Test async behavior**:
1. Open large file with long git history
2. Press `<leader>gb`
3. Verify you can still interact with Neovim while blame loads

### Common Issues

**"Error: No file in current buffer"**:
- Current buffer has no filename (e.g., scratch buffer)
- Solution: Open an actual file first

**"Error: File is not readable"**:
- File hasn't been saved to disk yet
- Solution: Save file with `:w` first

**"Error: git executable not found in PATH"**:
- Git not installed or not in PATH
- Solution: Install git or fix PATH

**Git blame shows error output**:
- File not in a git repository
- File not tracked by git
- Solution: Initialize git repo or track the file

**Debug logs not appearing**:
- `util.enable_log()` not called
- Neovim log level too high
- Solution: Call `enable_log()` in init.lua and check `:messages`

### Code Style

**Conventions**:
- **snake_case**: All variables and functions
- **4-space indentation**: No tabs (verify with `:set expandtab`)
- **Early returns**: Validate and fail fast
- **Module pattern**: `local M = {}` ... `return M`
- **Scheduled callbacks**: All async results in `vim.schedule()`

**Error Handling**:
- Use `vim.notify()` for user-facing errors
- Check buffer validity before operations: `vim.api.nvim_buf_is_valid()`
- Validate function inputs (nil checks)

**Naming**:
- Functions: verb + noun (e.g., `show_blame`, `create_buffer`)
- State variables: descriptive nouns (e.g., `source_buf`, `blame_win`)
- Booleans: is/has prefix (though not used in current code)

### Adding Features

**Example: Add commit detail viewer**:
1. Add keymap in `create_blame_buffer()`:
   ```lua
   vim.keymap.set('n', '<CR>', show_commit_details, {
       buffer = bufnr,
       desc = 'Show commit details'
   })
   ```

2. Implement `show_commit_details()`:
   ```lua
   local function show_commit_details()
       local line_num = vim.api.nvim_win_get_cursor(0)[1]
       local line = vim.api.nvim_buf_get_lines(state.blame_buf, line_num - 1, line_num, false)[1]
       local hash = get_commit_hash(line)

       -- Run git show
       vim.system({'git', 'show', hash}, {text = true}, function(obj)
           vim.schedule(function()
               -- Display in new buffer or floating window
           end)
       end)
   end
   ```

**Example: Add cursor synchronization**:
1. Create autocmds after blame is shown
2. Track CursorMoved in both buffers
3. Sync line numbers between windows
4. Use flag to prevent infinite loops

## Integration

### With Main Config
Typically loaded in `vim/nvim/init.lua`:

```lua
require('gitblame').setup()
```

### With Other Plugins
**Compatible with**:
- fugitive.vim (different features, no conflict)
- gitsigns.nvim (inline git status)
- diffview.nvim (visual diffs)

**Potential conflicts**:
- Other blame plugins (e.g., git-blame.nvim)
- Keymap conflicts on `<leader>gb` (check existing mappings)

## Limitations

**Current Implementation**:
- No cursor synchronization between source and blame windows
- No inline blame annotations (virtual text)
- No commit detail viewer
- Time-travel doesn't show historical file content (only blame)
- No syntax highlighting for blame output
- Window position fixed to left (not configurable)
- No cleanup of blame window when source closes

**Neovim Version Requirements**:
- Requires Neovim 0.10+ (`vim.system` API)
- Uses modern API (`nvim_set_option_value` instead of deprecated functions)

## Future Enhancement Ideas

- Configurable window position (left/right/bottom)
- Cursor synchronization between source and blame
- Commit detail floating window (press `<CR>` on blame line)
- Virtual text blame annotations (inline in source)
- Syntax highlighting for blame output (highlight commits, dates, authors)
- Auto-close blame when source buffer closes
- Configurable keymaps
- Historical file content viewing (when time-traveling)
- Git log integration
- Diff viewing
- Commit filtering/search
