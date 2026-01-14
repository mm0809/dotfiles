-- ============================================================================
-- Gitblame Plugin - UI Utilities
-- ============================================================================
-- Provides utility functions for creating and managing buffers and windows.
-- ============================================================================

local M = {}

---Create a scratch buffer with standard options
---@param buftype string Buffer type (e.g., 'nofile')
---@param filetype string|nil Filetype to set
---@param name string|nil Buffer name
---@return integer bufnr Buffer number
function M.create_buffer(buftype, filetype, name)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('buftype', buftype, {buf = buf})
    vim.api.nvim_set_option_value('bufhidden', 'wipe', {buf = buf})
    vim.api.nvim_set_option_value('swapfile', false, {buf = buf})
    vim.api.nvim_set_option_value('modifiable', false, {buf = buf})

    if filetype then
        vim.api.nvim_set_option_value('filetype', filetype, {buf = buf})
    end

    if name then
        vim.api.nvim_buf_set_name(buf, name)
    end

    return buf
end

---Render lines to a buffer
---@param bufnr integer Buffer number
---@param lines table Array of lines to display
function M.render_buffer(bufnr, lines)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.api.nvim_set_option_value('modifiable', true, {buf = bufnr})
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, {buf = bufnr})
end

---Create a centered floating window
---@param lines table Array of lines to display
---@param opts table|nil Configuration options (width, height, relative, border, filetype)
---@return integer bufnr Buffer number
---@return integer winnr Window ID
function M.create_floating_window(lines, opts)
    opts = opts or {}

    local width = opts.width or 80
    local height = opts.height or math.min(#lines + 2, 20)
    local relative = opts.relative or 'editor'
    local border = opts.border or 'rounded'

    local ui_width = vim.o.columns
    local ui_height = vim.o.lines
    local col = math.max(0, math.floor((ui_width - width) / 2))
    local row = math.max(0, math.floor((ui_height - height) / 2))

    local buf = M.create_buffer('nofile', opts.filetype, nil)
    M.render_buffer(buf, lines)

    local win_config = {
        relative = relative,
        width = width,
        height = height,
        col = col,
        row = row,
        style = 'minimal',
        border = border,
        zindex = 1000,
    }

    local win = vim.api.nvim_open_win(buf, true, win_config)

    vim.api.nvim_set_option_value('cursorline', false, {win = win})
    vim.api.nvim_set_option_value('number', false, {win = win})
    vim.api.nvim_set_option_value('relativenumber', false, {win = win})
    vim.api.nvim_set_option_value('wrap', true, {win = win})

    return buf, win
end

return M
