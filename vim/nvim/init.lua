require("options")
require("lsp")

vim.cmd("colorscheme gruvbox")

vim.keymap.set('i', 'jj', '<Esc>')
vim.keymap.set('n', 'gl', '<cmd>lua vim.diagnostic.open_float()<cr>')
