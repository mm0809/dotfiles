-- must before require("lsp")
clangd_path='/home/zklin/program/clangd_20.1.8/bin/clangd'

require("options")
require("lsp")

vim.cmd("colorscheme gruvbox")

vim.g.mapleader = " "

vim.keymap.set('i', 'jj', '<Esc>')
vim.keymap.set('n', 'gl', '<cmd>lua vim.diagnostic.open_float()<cr>')

-- delete or paste without yanking
vim.keymap.set('v', '<leader>d', '"_d')
vim.keymap.set('v', '<leader>p', '"_dP')

vim.keymap.set('n', '<C-p>', ':FZF<CR>')

local function reload_plugin(plugin_name)
    -- 1. unload relate module
    for module_name, _ in pairs(package.loaded) do
        if module_name:find('^' .. plugin_name) then
            package.loaded[module_name] = nil
            vim.notify(module_name .. ' unload', vim.log.levels.INFO)
        end
    end

    -- 2. reload module
    local ok, err = pcall(require, plugin_name)
    if ok then
        require(plugin_name).setup()
        vim.notify('✓ ' .. plugin_name .. ' reloaded', vim.log.levels.INFO)
    else
        vim.notify('✗ Reload failed: ' .. tostring(err), vim.log.levels.ERROR)
    end
end

vim.keymap.set('n', '<leader>rr', function()
    reload_plugin('gitblame')
end)

-- local dev_mode = true  -- Set to false in production
--
-- if dev_mode then
--     -- Auto-reload on save
--     vim.api.nvim_create_autocmd('BufWritePost', {
--         pattern = '*/lua/gitblame/*.lua',
--         callback = function()
--             package.loaded['gitblame'] = nil
--             local ok, err = pcall(require, 'gitblame')
--             if ok then
--                 require('gitblame').setup()
--                 vim.notify('✓ Gitblame reloaded', vim.log.levels.INFO)
--             else
--                 vim.notify('✗ Reload failed: ' .. tostring(err), vim.log.levels.ERROR)
--             end
--         end,
--     })
-- end

require("gitblame").setup()
