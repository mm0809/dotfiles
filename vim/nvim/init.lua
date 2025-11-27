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
