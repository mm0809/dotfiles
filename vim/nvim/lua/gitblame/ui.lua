local M = {}
---Create a scratch buffer with standard options.
---@param buftype string Buffer type (e.g., 'nofile')
---@param filetype string|nil Filetype to set
---@param name string|nil Buffer name
---@return integer bufnr
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

function M.render_buffer(bufnr, lines)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    vim.api.nvim_set_option_value('modifiable', true, {buf = bufnr})
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, {buf = bufnr})
end

return M
