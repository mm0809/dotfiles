-- ============================================================================
-- Gitblame Plugin - Main Module
-- ============================================================================
-- A Neovim plugin for viewing git blame in a split window with time-travel
-- capabilities and commit detail viewing.
--
-- Features:
--   - Split window git blame viewer
--   - Time-travel: press '-' to view blame before a commit
--   - Commit details: press '<CR>' to view commit in floating window
--   - Configurable window position and appearance
--
-- Usage:
--   require('gitblame').setup()
--   Then use <leader>gb or :Gitblame command
-- ============================================================================

local util = require('gitblame.util')
local ui = require('gitblame.ui')

util.enable_log()

local M = {}

-- ============================================================================
-- State Management
-- ============================================================================

local state = {
    filepath = nil,
    source_buf = nil,
    source_win = nil,
    blame_buf = nil,
    blame_win = nil,
    floating_buf = nil,
    floating_win = nil
}

local sync_state = {
    syncing = false,      -- Prevents infinite recursion
    enabled = false,      -- Whether sync is currently active
    source_autocmd = nil, -- Autocmd ID for source window
    blame_autocmd = nil   -- Autocmd ID for blame window
}

-- ============================================================================
-- Configuration
-- ============================================================================

local config = {
    git_blame_args = {'--date=short'},
    window = {
        position = 'left',      -- 'left' | 'right'
        width = 80,             -- Column width (0 = no resize)
        focus_on_open = true    -- Focus blame window after opening
    },
    floating_window = {
        width = 90,
        max_height = 40,
        border = 'rounded',     -- 'none', 'single', 'double', 'rounded', 'solid'
        relative = 'editor'     -- 'editor', 'cursor', 'win'
    },
    sync = {
        enabled = true,         -- Enable cursor sync by default
        insert_mode = false     -- Don't sync in insert mode
    }
}

-- ============================================================================
-- Validation and Initialization
-- ============================================================================

local function init()
    state.filepath = vim.fn.expand('%:p')

    if state.filepath == nil or state.filepath == '' then
        vim.notify('Error: No file in current buffer', vim.log.levels.ERROR)
        return false
    end

    if vim.fn.filereadable(state.filepath) == 0 then
        vim.notify('Error: File is not readable', vim.log.levels.ERROR)
        return false
    end

    if vim.fn.executable('git') == 0 then
        vim.notify('Error: git executable not found in PATH', vim.log.levels.ERROR)
        return false
    end

    state.source_buf = vim.api.nvim_get_current_buf()
    state.source_win = vim.api.nvim_get_current_win()
    return true
end

-- ============================================================================
-- Window Management
-- ============================================================================

local function open_blame_window(buf)
    local current_win = vim.api.nvim_get_current_win()

    local split_cmd = config.window.position == 'right'
        and 'rightbelow vsplit'
        or 'leftabove vsplit'
    vim.cmd(split_cmd)

    state.blame_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.blame_win, buf)

    vim.api.nvim_set_option_value('number', false, { win = state.blame_win })
    vim.api.nvim_set_option_value('relativenumber', false, { win = state.blame_win })
    vim.api.nvim_set_option_value('wrap', false, { win = state.blame_win })

    if config.window.width and config.window.width > 0 then
        pcall(vim.cmd, string.format('vertical resize %d', config.window.width))
    end

    if not config.window.focus_on_open then
        vim.api.nvim_set_current_win(current_win)
    end
end

-- ============================================================================
-- Cursor Synchronization
-- ============================================================================

---Synchronize cursor position from source window to blame window (or vice versa)
---@param from_source boolean True if syncing from source to blame
local function sync_cursor(from_source)
    -- Guard: Check if sync is enabled and not already syncing
    if not sync_state.enabled or sync_state.syncing then
        return
    end

    -- Guard: Validate both windows exist
    if not state.source_win or not vim.api.nvim_win_is_valid(state.source_win) then
        return
    end
    if not state.blame_win or not vim.api.nvim_win_is_valid(state.blame_win) then
        return
    end

    -- Get current window (the one user is in)
    local current_win = vim.api.nvim_get_current_win()

    -- Determine source and target windows
    local source_win = from_source and state.source_win or state.blame_win
    local target_win = from_source and state.blame_win or state.source_win
    local target_buf = from_source and state.blame_buf or state.source_buf

    -- Get cursor position from source window
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, source_win)
    if not ok then
        return
    end

    local row = cursor[1]

    -- Guard: Check if target line exists
    local target_line_count = vim.api.nvim_buf_line_count(target_buf)
    if row > target_line_count then
        row = target_line_count
    end

    -- Set sync flag to prevent infinite loop
    sync_state.syncing = true

    -- Set cursor in target window without triggering autocmds
    pcall(function()
        vim.api.nvim_win_set_cursor(target_win, {row, 0})
    end)

    -- Restore sync flag
    sync_state.syncing = false

    -- Ensure we stay in the window user was in
    if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
    end
end

---Cleanup cursor synchronization autocmds
local function cleanup_cursor_sync()
    -- Delete autocmds if they exist
    if sync_state.source_autocmd then
        pcall(vim.api.nvim_del_autocmd, sync_state.source_autocmd)
        sync_state.source_autocmd = nil
    end

    if sync_state.blame_autocmd then
        pcall(vim.api.nvim_del_autocmd, sync_state.blame_autocmd)
        sync_state.blame_autocmd = nil
    end

    -- Clear augroup
    pcall(vim.api.nvim_clear_autocmds, {group = 'GitblameCursorSync'})

    sync_state.enabled = false
    util.log('Cursor sync disabled')
end

---Setup cursor synchronization autocmds
local function setup_cursor_sync()
    -- Don't setup if sync is disabled in config
    if not config.sync.enabled then
        return
    end

    -- Clear any existing autocmds
    cleanup_cursor_sync()

    -- Create augroup for sync
    local group = vim.api.nvim_create_augroup('GitblameCursorSync', {clear = true})

    -- Events to listen for
    local events = {'CursorMoved'}
    if config.sync.insert_mode then
        table.insert(events, 'CursorMovedI')
    end

    -- Setup autocmd for source window
    sync_state.source_autocmd = vim.api.nvim_create_autocmd(events, {
        group = group,
        buffer = state.source_buf,
        callback = function()
            sync_cursor(true)  -- Sync from source to blame
        end,
        desc = 'Sync cursor from source to blame window'
    })

    -- Setup autocmd for blame window
    sync_state.blame_autocmd = vim.api.nvim_create_autocmd(events, {
        group = group,
        buffer = state.blame_buf,
        callback = function()
            sync_cursor(false)  -- Sync from blame to source
        end,
        desc = 'Sync cursor from blame to source window'
    })

    sync_state.enabled = true
    util.log('Cursor sync enabled')
end

-- ============================================================================
-- Git Blame Operations
-- ============================================================================

local function show_blame(hash)
    local cwd = vim.fn.fnamemodify(state.filepath, ':h')

    local cmd = {'git', 'blame'}
    for _, flag in ipairs(config.git_blame_args or {}) do
        table.insert(cmd, flag)
    end
    if hash then
        table.insert(cmd, hash .. '^')
        table.insert(cmd, '--')
    end
    table.insert(cmd, state.filepath)

    vim.schedule(function()
        ui.render_buffer(state.blame_buf, {'Running git blame..'})
    end)

    local on_exit = function(obj)
        vim.schedule(function()
            local lines = util.str_to_table(obj.code == 0 and obj.stdout or obj.stderr)
            ui.render_buffer(state.blame_buf, lines)

            -- Re-sync cursor after blame updates
            if sync_state.enabled then
                -- Wait a tiny bit for buffer to settle
                vim.defer_fn(function()
                    sync_cursor(true)  -- Sync from source to blame
                end, 10)
            end
        end)
    end

    vim.system(cmd, {cwd = cwd, text = true}, on_exit)
end

local function get_commit_hash(line)
    return line and line ~= '' and line:match('^(%x+)') or nil
end

local function get_current_blame_line()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    return vim.api.nvim_buf_get_lines(state.blame_buf, line_num - 1, line_num, false)[1]
end

local function show_blame_before()
    util.log('show_blame_before')
    local hash = get_commit_hash(get_current_blame_line())
    util.log('hash', hash)
    show_blame(hash)
end

-- ============================================================================
-- Floating Window (Commit Details)
-- ============================================================================

local function close_floating_window()
    util.log('close_floating_window')

    if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
        vim.api.nvim_win_close(state.floating_win, true)
    end

    state.floating_win = nil
    state.floating_buf = nil
end

local function show_commit_details()
    util.log('show_commit_details')
    local hash = get_commit_hash(get_current_blame_line())

    if not hash then
        vim.notify('Error: Could not extract commit hash from blame line', vim.log.levels.WARN)
        return
    end

    util.log('Showing commit details for hash', hash)

    close_floating_window()

    local cwd = vim.fn.fnamemodify(state.filepath, ':h')
    local cmd = {'git', 'show', hash}

    local loading_lines = {'Loading commit details...'}
    state.floating_buf, state.floating_win = ui.create_floating_window(loading_lines, {
        filetype = 'git',
        width = config.floating_window.width,
        height = config.floating_window.max_height,
        border = config.floating_window.border,
        relative = config.floating_window.relative,
    })

    vim.keymap.set('n', 'q', close_floating_window, {
        buffer = state.floating_buf,
        noremap = true,
        silent = true,
        desc = 'Close commit details window',
    })

    vim.system(cmd, {cwd = cwd, text = true}, function(obj)
        vim.schedule(function()
            if not state.floating_buf or not vim.api.nvim_buf_is_valid(state.floating_buf) then
                return
            end

            local output = obj.code == 0 and obj.stdout or ('Error: ' .. (obj.stderr or 'Unknown error'))
            local lines = util.str_to_table(output)
            ui.render_buffer(state.floating_buf, lines)

            if state.floating_win and vim.api.nvim_win_is_valid(state.floating_win) then
                local new_height = math.min(#lines + 2, config.floating_window.max_height)
                vim.api.nvim_win_set_height(state.floating_win, new_height)
            end
        end)
    end)
end

-- ============================================================================
-- Buffer Setup
-- ============================================================================

local function create_blame_buffer()
    util.log('create_blame_buffer')
    local bufnr = ui.create_buffer('nofile', 'git', 'gitblame://output')

    vim.keymap.set('n', '-', show_blame_before, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Show blame before this commit',
    })

    vim.keymap.set('n', '<CR>', show_commit_details, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Show commit details in floating window',
    })

    -- Add sync toggle keymap
    vim.keymap.set('n', 's', function()
        if sync_state.enabled then
            cleanup_cursor_sync()
            vim.notify('Cursor sync disabled', vim.log.levels.INFO)
        else
            setup_cursor_sync()
            vim.notify('Cursor sync enabled', vim.log.levels.INFO)
        end
    end, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Toggle cursor synchronization',
    })

    -- Setup autocmd to cleanup when blame buffer is hidden/closed
    vim.api.nvim_create_autocmd({'BufWipeout', 'BufDelete', 'BufUnload'}, {
        buffer = bufnr,
        callback = function()
            cleanup_cursor_sync()
            util.log('Blame buffer closed, sync cleaned up')
        end,
        once = true,
        desc = 'Cleanup cursor sync when blame closes'
    })

    state.blame_buf = bufnr
end

-- ============================================================================
-- Main Entry Point
-- ============================================================================

local function git_blame()
    util.log('git_blame')

    if not init() then
        return
    end

    create_blame_buffer()
    open_blame_window(state.blame_buf)
    show_blame()

    -- Setup cursor sync after windows are created
    setup_cursor_sync()
end

-- ============================================================================
-- Plugin Setup
-- ============================================================================

function M.setup(opts)
    config = vim.tbl_deep_extend('force', config, opts or {})

    util.log('Setup')

    vim.api.nvim_create_user_command('Gitblame', function()
        git_blame()
    end, { desc = 'Open a git blame split window for current file' })

    vim.keymap.set('n', '<leader>gb', '<cmd>Gitblame<CR>')
end

return M
