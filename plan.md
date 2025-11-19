# Plan for Submodule Management Script

## Overview
Develop a Bash script to manage Git submodules in the `vim/site/pack/default/start` directory. This directory hosts Vim plugins as Git submodules (e.g., fzf and gruvbox.nvim). The script will simplify common submodule operations, ensuring efficient plugin management without manual Git commands.

## Objectives
- Provide a user-friendly interface for submodule operations.
- Automate repetitive tasks like adding, updating, and removing plugins.
- Ensure safety by confirming destructive actions (e.g., removal).
- Support batch operations where applicable.

## Requirements
- Bash shell (compatible with Linux systems).
- Git installed and configured.
- Execution from the repository root (where `.gitmodules` resides).
- Basic error handling and user feedback.

## Key Features
1. **List Submodules**: Display all current submodules, including their paths, URLs, and current commits.
2. **Add Submodule**: Add a new plugin as a submodule from a Git URL, specifying a local name.
3. **Update Submodules**: Update all submodules to the latest commits on their tracked branches.
4. **Remove Submodule**: Safely remove a submodule, including cleanup of `.gitmodules`, the submodule directory, and Git index.
5. **Status Check**: Show the status of submodules (e.g., modified, untracked changes).
6. **Help**: Display usage instructions.

## Implementation Details
- **Script Name**: `manage_submodules.sh`
- **Location**: Place in the repository root for easy access.
- **Command-Line Interface**: Use flags for operations (e.g., `--list`, `--add <url> [pname]`, `--update`, `--remove <name>`, `--status`, `--help`).
- **Git Integration**: Leverage `git submodule` commands internally.
- **Safety Measures**:
  - Confirm before removing submodules.
  - Check for uncommitted changes before updates.
- **Error Handling**: Exit with appropriate codes and messages for failures (e.g., invalid URL, submodule not found).
- **Dependencies**: None beyond standard Bash and Git.

## Usage Examples

### 1. List Submodules
**Command:** `./manage_submodules.sh --list`

**Description:** Displays all current submodules, including their paths, URLs, and current commit hashes.

**Underlying Git Commands:** `git submodule status`, `git config --get submodule.<name>.url`

**Expected Output Format:**
```
Submodules:
- fzf (vim/site/pack/default/start/fzf) [abcd1234] https://github.com/junegunn/fzf.git
- gruvbox.nvim (vim/site/pack/default/start/gruvbox.nvim) [efgh5678] https://github.com/ellisonleao/gruvbox.nvim.git
```

**Files/Folders Created/Modified:** None

### 2. Add a Plugin
**Command:** `./manage_submodules.sh --add https://github.com/user/plugin.git [plugin-name]`

**Description:** Adds a new plugin as a submodule from the specified Git URL. Uses the provided local name, or defaults to the repository name from the URL (e.g., 'nvim-window-picker' for https://github.com/s1n7ax/nvim-window-picker).

**Underlying Git Commands:** `git submodule add <url> <path>`

**Expected Output Format:**
```
Adding submodule 'plugin-name'...
Submodule 'plugin-name' added successfully.
```

**Files/Folders Created/Modified:**
- Creates directory: `vim/site/pack/default/start/plugin-name` (cloned repository)
- Modifies: `.gitmodules` (adds new submodule entry)
- Updates Git index: Adds the submodule to the repository index

### 3. Update All Submodules
**Command:** `./manage_submodules.sh --update`

**Description:** Updates all submodules to the latest commits on their tracked branches.

**Underlying Git Commands:** `git submodule update --remote`

**Expected Output Format:**
```
Updating submodules...
Updating fzf... Done.
Updating gruvbox.nvim... Done.
All submodules updated successfully.
```

**Files/Folders Created/Modified:** None (updates existing submodule directories with new commits)

### 4. Remove a Plugin
**Command:** `./manage_submodules.sh --remove plugin-name`

**Description:** Safely removes the specified submodule, including cleanup of `.gitmodules`, the submodule directory, and Git index. Prompts for confirmation before removal.

**Underlying Git Commands:** `git submodule deinit <path>`, `git rm <path>`, `git config --remove-section submodule.<name>`

**Expected Output Format:**
```
Are you sure you want to remove submodule 'plugin-name'? (y/N): y
Removing submodule 'plugin-name'...
Submodule 'plugin-name' removed successfully.
```

**Files/Folders Created/Modified:**
- Removes directory: `vim/site/pack/default/start/plugin-name`
- Modifies: `.gitmodules` (removes submodule entry)
- Updates Git index: Removes the submodule from the repository index

### 5. Check Status
**Command:** `./manage_submodules.sh --status`

**Description:** Shows the status of all submodules, indicating if they are modified, have untracked changes, or are up-to-date.

**Underlying Git Commands:** `git submodule status`

**Expected Output Format:**
```
Submodule status:
 fzf vim/site/pack/default/start/fzf (abcd1234)
+gruvbox.nvim vim/site/pack/default/start/gruvbox.nvim (efgh5678)
```

**Files/Folders Created/Modified:** None

## Implementation Status

### Completed Features
- ✅ **Script Created**: `manage_submodules.sh` implemented with all core features
- ✅ **Color-coded Output**: Added visual feedback with colored messages (green for success, red for errors, yellow for warnings)
- ✅ **Auto-name Extraction**: Automatically extracts plugin name from URL if not provided
- ✅ **Git Repository Check**: Validates that script is run from a git repository
- ✅ **Safety First**: All destructive operations (e.g., removal) require user confirmation
- ✅ **Help Documentation**: Comprehensive help message with usage examples
- ✅ **Error Handling**: Proper error messages and exit codes

### Technical Details
- **Script Location**: Repository root (`manage_submodules.sh`)
- **Executable**: Set with `chmod +x manage_submodules.sh`
- **Shell**: Bash with `set -e` for strict error handling
- **Dependencies**: Git only (no external tools required)

### Tested Operations
- `--list`: Successfully displays current submodules (fzf and gruvbox.nvim)
- `--status`: Shows git submodule status output
- `--help`: Displays comprehensive usage information

## Potential Enhancements (Future)
- Support for updating specific submodules (e.g., `--update <name>`).
- Integration with Vim plugin managers (if needed).
- Logging of operations to a file.
- Support for different branch tracking per submodule.
- Batch operations with multiple names for add/remove.

## Risks and Considerations
- Ensure the script runs from the correct directory to avoid affecting other parts of the repository.
- Test on a copy of the repository to prevent accidental data loss.
- Handle edge cases like nested submodules or conflicts during updates.
- The script uses `set -e` which will exit on any command failure - may need refinement for complex error scenarios.