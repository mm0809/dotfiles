-- must before require("lsp")
clangd_path = '/home/zklin/program/clangd_20.1.8/bin/clangd'

require("options")
require("lsp")
require("keymaps")

vim.cmd("colorscheme gruvbox")

require("gitblame").setup()
