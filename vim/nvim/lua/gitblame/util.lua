local M = {}

local DEBUG = false

function M.enable_log()
    DEBUG = true
end

function M.disable_log()
    DEBUG = false
end

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

function M.str_to_table(str)
    local lines = vim.split(str, '\n', {plain = true})

    -- remove the last line if it is empty
    if lines[#lines] == '' then
        table.remove(lines)
    end

    return lines
end

return M
