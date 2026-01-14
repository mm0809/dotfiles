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
