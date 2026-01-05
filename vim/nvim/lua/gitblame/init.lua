local util = require('gitblame.util')
local ui = require('gitblame.ui')

util.enable_log()

local M = {}

local state = {
    filepath = nil,
    source_buf = nil,
    source_win = nil,
    blame_buf = nil,
    blame_win = nil
}

local config = {
    git_blame_args = {'--date=short'}
}

local function init()
    state.filepath = vim.fn.expand('%:p')

    if state.filepath == nil or state.filepath == '' then
        vim.notify('Error: No file in current buffer.', vim.log.levels.ERROR)
        return
    end

    if vim.fn.filereadable(state.filepath) == 0 then
        vim.notify('Error: File is not readable', vim.log.levels.ERROR)
        return
    end

    if vim.fn.executable('git') == 0 then
        vim.notify('Error: git executable not found in PATH.', vim.log.levels.ERROR)
        return
    end

    state.source_buf = vim.api.nvim_get_current_buf()
    state.source_win = vim.api.nvim_get_current_win()
end

local function open_blame_window(buf)
    vim.cmd('leftabove vsplit')

    state.blame_win = vim.api.nvim_get_current_win()

    vim.api.nvim_win_set_buf(state.blame_win, buf)
    vim.api.nvim_set_option_value('number', false, { win = state.blame_win })
    vim.api.nvim_set_option_value('relativenumber', false, { win = state.blame_win })
    vim.api.nvim_set_option_value('wrap', false, { win = state.blame_win })
end

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
            local lines
            if obj.code == 0 then
                lines = util.str_to_table(obj.stdout)
                ui.render_buffer(state.blame_buf, lines)
            else
                lines = util.str_to_table(obj.stderr)
                ui.render_buffer(state.blame_buf, lines)
            end
        end)
    end

    vim.system(cmd, {cwd = cwd, text = true}, on_exit)
end

local function get_commit_hash(line)
    if not line or line == '' then
        return nil
    end

    local hash = line:match('^(%x+)')

    return hash
end

local function show_blame_before()
    util.log('show_blame_before')

    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(state.blame_buf, line_num - 1, line_num, false)[1]
    local hash = get_commit_hash(line)

    util.log('hash', hash)

    show_blame(hash)
end

local function create_blame_buffer()
    util.log('create_blame_buffer')
    -- TODO: there is no gitblame filetype
    local bufnr = ui.create_buffer('nofile', 'gitblame', 'gitblame://output')

    -- Set up keymap to show blame before commit
    vim.keymap.set('n', '-', show_blame_before, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Show blame before this commit',
    })

    state.blame_buf = bufnr
end

local function git_blame()
    util.log('show_blame')

    -- 0. init state
    init()

    -- 1. create blame buffer
    create_blame_buffer()

    -- 2. open blame window
    open_blame_window(state.blame_buf)

    -- 3. get blame messages and show on buffer
    show_blame()
end

function M.setup()
    util.log('Setup')

    vim.api.nvim_create_user_command('Gitblame', function()
        git_blame()
    end, { desc = 'Open a git blame split window for current file' })

    vim.keymap.set('n', '<leader>gb', '<cmd>Gitblame<CR>')
end

return M
