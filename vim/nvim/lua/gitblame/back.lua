local M = {}

---Default configuration for the git blame split.
local default_config = {
    window = {
        width = 80,              -- Width of the vertical split
        position = 'left',       -- 'left' | 'right'
        focus_on_open = true,    -- Focus the blame window when it opens
    },
    git = {
        blame_args = { '--date=iso' }, -- Extra arguments passed to `git blame`
    },
    keymaps = {
        blame = '<leader>gb',    -- Normal-mode mapping to trigger :Gitblame (set to nil to disable)
    },
    messages = {
        prefix = '[gitblame]',
    },
}

local DEBUG = false

-- Constants
local MIN_COMMIT_HASH_LENGTH = 7
local SHORT_HASH_LENGTH = 7
local FLOAT_WIDTH_RATIO = 0.8
local FLOAT_HEIGHT_RATIO = 0.8

local function debug_log(msg, data)
    if not DEBUG then return end

    if data then
        vim.notify('[DEBUG] ' .. msg .. ': ' .. vim.inspect(data), vim.log.levels.DEBUG)
    else
        vim.notify('[DEBUG] ' .. msg, vim.log.levels.DEBUG)
    end
end

---Runtime configuration (mutated during setup).
---@type table
local config = vim.deepcopy(default_config)

---Internal state handled by the module.
local state = {
    bufnr = nil,
    winid = nil,
    job_id = nil,
    source_winid = nil,
    source_bufnr = nil,
    source_line = nil,
    syncing = false,
    autocmd_group = nil,
    float_winid = nil,
    float_bufnr = nil,
}

---Utility wrapper around vim.notify with a consistent prefix.
---@param msg string
---@param level integer|nil
local function notify(msg, level)
    vim.notify(string.format('%s %s', config.messages.prefix, msg), level or vim.log.levels.INFO)
end

---Extract commit hash from a blame line.
---@param line string
---@return string|nil
local function extract_commit_hash(line)
    if not line or line == '' then
        return nil
    end

    -- Git blame format: <commit_hash> (author date time line_num) content
    -- Commit hash is at the beginning and is 40 characters (or 7+ for short hash)
    local hash = line:match('^(%x+)')

    if hash and #hash >= MIN_COMMIT_HASH_LENGTH then
        return hash
    end

    return nil
end

---Set entire buffer content, temporarily toggling modifiability.
---@param bufnr integer
---@param lines string[]
local function render_lines(bufnr, lines)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

---Create a scratch buffer with standard options.
---@param buftype string Buffer type (e.g., 'nofile')
---@param filetype string|nil Filetype to set
---@param name string|nil Buffer name
---@return integer bufnr
local function create_scratch_buffer(buftype, filetype, name)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', buftype)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

    if filetype then
        vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype)
    end

    if name then
        vim.api.nvim_buf_set_name(bufnr, name)
    end

    return bufnr
end

---Create standard stdout/stderr handlers for git commands.
---@return table handlers Table with on_stdout, on_stderr, and get_output()
local function create_git_output_handlers()
    local stdout_lines = {}
    local stderr_lines = {}

    return {
        on_stdout = function(_, data)
            if not data then return end
            for _, line in ipairs(data) do
                if line and line ~= '' then
                    table.insert(stdout_lines, line)
                end
            end
        end,
        on_stderr = function(_, data)
            if not data then return end
            for _, line in ipairs(data) do
                if line and line ~= '' then
                    table.insert(stderr_lines, line)
                end
            end
        end,
        get_output = function()
            return stdout_lines, stderr_lines
        end,
    }
end

---Stop an active job if one is running.
local function stop_active_job()
    if state.job_id and state.job_id > 0 then
        pcall(vim.fn.jobstop, state.job_id)
        state.job_id = nil
    end
end

---Comprehensive cleanup of all state.
local function cleanup_state()
    stop_active_job()
    close_float()

    if state.autocmd_group then
        pcall(vim.api.nvim_clear_autocmds, { group = state.autocmd_group })
        state.autocmd_group = nil
    end

    state.winid = nil
    state.source_winid = nil
    state.source_bufnr = nil
    state.source_line = nil
    state.bufnr = nil
    state.float_winid = nil
    state.float_bufnr = nil
    state.syncing = false
end

---Close the floating window if it exists.
local function close_float()
    if state.float_winid and vim.api.nvim_win_is_valid(state.float_winid) then
        vim.api.nvim_win_close(state.float_winid, true)
    end
    state.float_winid = nil
    state.float_bufnr = nil
end

---Show commit details in a floating window.
local function show_commit_in_float()
    if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
        notify('Blame buffer not available', vim.log.levels.WARN)
        return
    end

    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= state.bufnr then
        return
    end

    -- Get current line
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(state.bufnr, line_num - 1, line_num, false)[1]

    if not line then
        notify('No line found', vim.log.levels.WARN)
        return
    end

    -- Extract commit hash
    local commit_hash = extract_commit_hash(line)
    if not commit_hash then
        notify('Could not extract commit hash from line', vim.log.levels.WARN)
        return
    end

    -- Close existing float if open
    close_float()

    -- Create floating window buffer
    local float_buf = create_scratch_buffer('nofile', 'gitcommit', nil)
    vim.api.nvim_buf_set_option(float_buf, 'modifiable', true)

    -- Calculate floating window size and position
    local ui = vim.api.nvim_list_uis()[1]
    local width = math.floor(ui.width * FLOAT_WIDTH_RATIO)
    local height = math.floor(ui.height * FLOAT_HEIGHT_RATIO)
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    -- Create floating window
    local float_win = vim.api.nvim_open_win(float_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = string.format(' Commit: %s ', commit_hash:sub(1, SHORT_HASH_LENGTH)),
        title_pos = 'center',
    })

    state.float_winid = float_win
    state.float_bufnr = float_buf

    -- Set up keymaps to close the float
    vim.keymap.set('n', 'q', close_float, { buffer = float_buf, noremap = true, silent = true })
    vim.keymap.set('n', '<Esc>', close_float, { buffer = float_buf, noremap = true, silent = true })

    -- Show loading message
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, { 'Loading commit details...' })

    -- Run git show asynchronously
    local handlers = create_git_output_handlers()
    local job_id = vim.fn.jobstart({ 'git', 'show', '--pretty=fuller', commit_hash }, {
        cwd = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(state.source_bufnr), ':h'),
        stdout_buffered = true,
        on_stdout = handlers.on_stdout,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(float_buf) then
                    return
                end

                local stdout_lines, _ = handlers.get_output()
                if exit_code == 0 and #stdout_lines > 0 then
                    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, stdout_lines)
                else
                    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, {
                        'Failed to load commit details.',
                        string.format('Exit code: %d', exit_code)
                    })
                end

                -- Set cursor to top
                if vim.api.nvim_win_is_valid(float_win) then
                    vim.api.nvim_win_set_cursor(float_win, { 1, 0 })
                end
            end)
        end,
    })

    if job_id <= 0 then
        vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, { 'Failed to start git show job' })
    end
end

---Get the parent commit hash for a given commit.
---@param commit_hash string
---@param cwd string
---@return string|nil parent_hash
local function get_parent_commit(commit_hash, cwd)
    local result = vim.fn.systemlist(string.format('git rev-parse %s^', commit_hash), cwd)
    if vim.v.shell_error == 0 and #result > 0 then
        return result[1]
    end
    notify(string.format('Failed to get parent commit for %s', commit_hash:sub(1, SHORT_HASH_LENGTH)), vim.log.levels.WARN)
    return nil
end

---Get file content at a specific commit.
---@param commit_hash string
---@param filepath string
---@param cwd string
---@return string[]|nil lines
local function get_file_at_commit(commit_hash, filepath, cwd)
    local relative_path = vim.fn.fnamemodify(filepath, ':.')
    local result = vim.fn.systemlist(string.format('git show %s:%s', commit_hash, relative_path), cwd)
    if vim.v.shell_error == 0 then
        return result
    end
    notify(string.format('Failed to retrieve file content from commit %s', commit_hash:sub(1, SHORT_HASH_LENGTH)), vim.log.levels.ERROR)
    return nil
end

---Show git blame before the commit on the current line.
local function show_blame_before_commit()
    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= state.bufnr then
        return
    end

    -- Get current line in blame buffer
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(state.bufnr, line_num - 1, line_num, false)[1]

    if not line then
        notify('No line found', vim.log.levels.WARN)
        return
    end

    -- Extract commit hash
    local commit_hash = extract_commit_hash(line)
    if not commit_hash then
        notify('Could not extract commit hash from line', vim.log.levels.WARN)
        return
    end

    -- Get the working directory from the source buffer
    if not state.source_bufnr or not vim.api.nvim_buf_is_valid(state.source_bufnr) then
        notify('Source buffer not available', vim.log.levels.ERROR)
        return
    end

    local source_filepath = vim.api.nvim_buf_get_name(state.source_bufnr)
    local cwd = vim.fn.fnamemodify(source_filepath, ':h')

    debug_log("source_filepath", source_filepath)
    debug_log("cwd", cwd)

    -- Get parent commit
    local parent_hash = get_parent_commit(commit_hash, cwd)
    if not parent_hash then
        notify(string.format('No parent commit found for %s', commit_hash:sub(1, SHORT_HASH_LENGTH)), vim.log.levels.WARN)
        return
    end

    -- Get file content at parent commit
    local file_lines = get_file_at_commit(parent_hash, source_filepath, cwd)
    if not file_lines then
        notify(string.format('Failed to get file content at commit %s', parent_hash:sub(1, SHORT_HASH_LENGTH)), vim.log.levels.ERROR)
        return
    end

    -- Create a new read-only buffer with the historical file content
    local source_ft = vim.api.nvim_buf_get_option(state.source_bufnr, 'filetype')
    local hist_bufnr = create_scratch_buffer('nofile', source_ft, nil)

    local filename = vim.fn.fnamemodify(source_filepath, ':t')
    vim.api.nvim_buf_set_name(hist_bufnr, string.format('%s@%s', filename, parent_hash:sub(1, SHORT_HASH_LENGTH)))

    -- Fill buffer with file content
    render_lines(hist_bufnr, file_lines)

    -- Open the buffer in the source window
    if state.source_winid and vim.api.nvim_win_is_valid(state.source_winid) then
        vim.api.nvim_win_set_buf(state.source_winid, hist_bufnr)
    else
        notify('Source window not available', vim.log.levels.ERROR)
        return
    end

    -- Update state to point to the new buffer
    state.source_bufnr = hist_bufnr
    state.source_line = line_num

    -- Stop any active job
    stop_active_job()

    -- Run git blame on the historical file
    notify(string.format('Loading blame for %s before %s...', filename, commit_hash:sub(1, SHORT_HASH_LENGTH)), vim.log.levels.INFO)

    -- We need to run git blame with the parent commit
    local args = { 'git', 'blame' }
    for _, flag in ipairs(config.git.blame_args or {}) do
        table.insert(args, flag)
    end
    table.insert(args, parent_hash)
    table.insert(args, '--')
    table.insert(args, vim.fn.fnamemodify(source_filepath, ':.'))

    local handlers = create_git_output_handlers()

    local job_id = vim.fn.jobstart(args, {
        cwd = cwd,
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = handlers.on_stdout,
        on_stderr = handlers.on_stderr,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                state.job_id = nil

                local stdout_lines, err_lines = handlers.get_output()
                if exit_code == 0 then
                    if #stdout_lines == 0 then
                        render_lines(state.bufnr, { 'git blame produced no output for this file.' })
                    else
                        render_lines(state.bufnr, stdout_lines)
                        -- Sync cursor to the same line
                        if state.winid and vim.api.nvim_win_is_valid(state.winid) and state.source_line then
                            pcall(vim.api.nvim_win_set_cursor, state.winid, { state.source_line, 0 })
                        end
                        -- Re-setup cursor synchronization with the new buffer
                        setup_cursor_sync()
                    end
                    return
                end

                local message = (#err_lines > 0 and table.concat(err_lines, '\n'))
                    or string.format('git blame failed with exit code %d', exit_code)
                render_lines(state.bufnr, { message })
                notify(message, vim.log.levels.ERROR)
            end)
        end,
    })

    if job_id <= 0 then
        state.job_id = nil
        local message = 'Failed to start git blame job'
        render_lines(state.bufnr, { message })
        notify(message, vim.log.levels.ERROR)
    else
        state.job_id = job_id
    end
end

---Ensure the scratch buffer used for blame output exists and is configured.
---@return integer bufnr
local function ensure_buffer()
    if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
        return state.bufnr
    end

    local bufnr = create_scratch_buffer('nofile', 'gitblame', 'gitblame://output')

    -- Set up keymap to show commit details
    vim.keymap.set('n', '<CR>', show_commit_in_float, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Show commit details in floating window',
    })

    -- Set up keymap to show blame before commit
    vim.keymap.set('n', '-', show_blame_before_commit, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = 'Show blame before this commit',
    })

    state.bufnr = bufnr
    return bufnr
end

---Open (or reuse) the left/right vertical split for the blame buffer.
---@param bufnr integer
local function open_blame_window(bufnr)
    local function set_window_buffer(win)
        vim.api.nvim_win_set_buf(win, bufnr)
        vim.api.nvim_set_option_value('number', false, { win = win })
        vim.api.nvim_set_option_value('relativenumber', false, { win = win })
        vim.api.nvim_set_option_value('wrap', false, { win = win })
    end

    -- Store the current window as the source window
    state.source_winid = vim.api.nvim_get_current_win()

    if state.winid and vim.api.nvim_win_is_valid(state.winid) then
        set_window_buffer(state.winid)
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    local split_cmd = config.window.position == 'right' and 'rightbelow vsplit' or 'leftabove vsplit'
    vim.cmd(split_cmd)

    state.winid = vim.api.nvim_get_current_win()
    set_window_buffer(state.winid)

    if config.window.width and config.window.width > 0 then
        pcall(vim.cmd, string.format('vertical resize %d', config.window.width))
    end

    if not config.window.focus_on_open then
        vim.api.nvim_set_current_win(current_win)
    end
end


---Sync cursor from source buffer to blame buffer.
local function sync_cursor_to_blame()
    if state.syncing then
        return
    end

    if not state.winid or not vim.api.nvim_win_is_valid(state.winid) then
        return
    end

    if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
        return
    end

    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= state.source_bufnr then
        return
    end

    local line = vim.api.nvim_win_get_cursor(0)[1]
    local blame_line_count = vim.api.nvim_buf_line_count(state.bufnr)

    if line <= blame_line_count then
        state.syncing = true
        pcall(vim.api.nvim_win_set_cursor, state.winid, { line, 0 })
        state.syncing = false
    end
end

---Sync cursor from blame buffer to source buffer.
local function sync_cursor_to_source()
    if state.syncing then
        return
    end

    if not state.source_winid or not vim.api.nvim_win_is_valid(state.source_winid) then
        return
    end

    if not state.source_bufnr or not vim.api.nvim_buf_is_valid(state.source_bufnr) then
        return
    end

    local current_buf = vim.api.nvim_get_current_buf()
    if current_buf ~= state.bufnr then
        return
    end

    local line = vim.api.nvim_win_get_cursor(0)[1]
    local source_line_count = vim.api.nvim_buf_line_count(state.source_bufnr)

    if line <= source_line_count then
        state.syncing = true
        pcall(vim.api.nvim_win_set_cursor, state.source_winid, { line, 0 })
        state.syncing = false
    end
end

---Setup cursor synchronization autocommands.
local function setup_cursor_sync()
    if not state.autocmd_group then
        state.autocmd_group = vim.api.nvim_create_augroup('GitblameCursorSync', { clear = true })
    else
        vim.api.nvim_clear_autocmds({ group = state.autocmd_group })
    end

    -- Sync from source to blame
    vim.api.nvim_create_autocmd('CursorMoved', {
        group = state.autocmd_group,
        buffer = state.source_bufnr,
        callback = sync_cursor_to_blame,
    })

    -- Sync from blame to source
    vim.api.nvim_create_autocmd('CursorMoved', {
        group = state.autocmd_group,
        buffer = state.bufnr,
        callback = sync_cursor_to_source,
    })

    -- Clean up when blame buffer is closed
    vim.api.nvim_create_autocmd('BufWipeout', {
        group = state.autocmd_group,
        buffer = state.bufnr,
        callback = function()
            cleanup_state()
        end,
    })
end

---Run `git blame` asynchronously and render the complete result once available.
---@param filepath string
---@param bufnr integer
local function run_git_blame_async(filepath, bufnr)
    local args = { 'git', 'blame' }
    for _, flag in ipairs(config.git.blame_args or {}) do
        table.insert(args, flag)
    end
    table.insert(args, filepath)

    local handlers = create_git_output_handlers()

    local job_id = vim.fn.jobstart(args, {
        cwd = vim.fn.fnamemodify(filepath, ':h'),
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = handlers.on_stdout,
        on_stderr = handlers.on_stderr,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                state.job_id = nil

                local stdout_lines, err_lines = handlers.get_output()
                if exit_code == 0 then
                    if #stdout_lines == 0 then
                        render_lines(bufnr, { 'git blame produced no output for this file.' })
                    else
                        render_lines(bufnr, stdout_lines)
                        -- Sync cursor to the source line
                        if state.winid and vim.api.nvim_win_is_valid(state.winid) and state.source_line then
                            pcall(vim.api.nvim_win_set_cursor, state.winid, { state.source_line, 0 })
                        end
                        -- Setup bidirectional cursor synchronization
                        setup_cursor_sync()
                    end
                    return
                end

                local message = (#err_lines > 0 and table.concat(err_lines, '\n'))
                    or string.format('git blame failed with exit code %d', exit_code)
                render_lines(bufnr, { message })
                notify(message, vim.log.levels.ERROR)
            end)
        end,
    })

    if job_id <= 0 then
        state.job_id = nil
        local message = 'Failed to start git blame job (is git installed?)'
        render_lines(bufnr, { message })
        notify(message, vim.log.levels.ERROR)
        return
    end

    state.job_id = job_id
end

---Primary entry point: validate state, prepare window, and launch the async job.
function M.show_blame()
    local filepath = vim.fn.expand('%:p')
    if filepath == nil or filepath == '' then
        notify('Error: No file in current buffer.', vim.log.levels.ERROR)
        return
    end

    if vim.fn.filereadable(filepath) == 0 then
        notify('Error: Current buffer has not been written to disk.', vim.log.levels.ERROR)
        return
    end

    if vim.fn.executable('git') == 0 then
        notify('Error: git executable not found in PATH.', vim.log.levels.ERROR)
        return
    end

    -- Capture current buffer and line before opening blame window
    state.source_bufnr = vim.api.nvim_get_current_buf()
    state.source_line = vim.api.nvim_win_get_cursor(0)[1]

    stop_active_job()

    local bufnr = ensure_buffer()
    open_blame_window(bufnr)

    render_lines(bufnr, { string.format('Running git blame for %s ...', vim.fn.fnamemodify(filepath, ':t')) })
    run_git_blame_async(filepath, bufnr)
end

---Setup entry point exposed to user configs.
---@param opts table|nil
function M.setup(opts)
    config = vim.tbl_deep_extend('force', vim.deepcopy(default_config), opts or {})

    vim.api.nvim_create_user_command('Gitblame', function()
        M.show_blame()
    end, { desc = 'Open a git blame split for the current file' })

    if config.keymaps and config.keymaps.blame and config.keymaps.blame ~= '' then
        vim.keymap.set('n', config.keymaps.blame, '<cmd>Gitblame<CR>', {
            desc = 'Show git blame in split window',
            noremap = true,
            silent = true,
        })
    end
end

return M
