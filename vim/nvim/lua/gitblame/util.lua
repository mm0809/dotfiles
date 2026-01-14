-- ============================================================================
-- Gitblame Plugin - Utility Functions
-- ============================================================================
-- Provides logging and string manipulation utilities.
-- ============================================================================

local M = {}

local DEBUG = false

---Enable debug logging
function M.enable_log()
    DEBUG = true
end

---Disable debug logging
function M.disable_log()
    DEBUG = false
end

---Log a debug message (only if DEBUG is enabled)
---@param msg string Message to log
---@param data any|nil Optional data to inspect
function M.log(msg, data)
    if not DEBUG then
        return
    end

    if data then
        vim.notify('[DEBUG] ' .. msg .. ': ' .. vim.inspect(data), vim.log.levels.DEBUG)
    else
        vim.notify('[DEBUG] ' .. msg, vim.log.levels.DEBUG)
    end
end

---Convert a string to a table of lines
---@param str string String to split
---@return table lines Array of lines
function M.str_to_table(str)
    local lines = vim.split(str, '\n', {plain = true})

    -- Remove trailing empty line
    if lines[#lines] == '' then
        table.remove(lines)
    end

    return lines
end

return M
