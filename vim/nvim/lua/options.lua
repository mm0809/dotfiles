vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4

vim.opt.cursorline = true

-- vim.opt.clipboard = "unnamedplus"

vim.opt.scrolloff = 999

vim.opt.virtualedit = "block"

vim.opt.inccommand = "split"

vim.opt.termguicolors = true

-- opt for auto complete menu
vim.opt.completeopt = { 'menu', 'menuone', 'noselect', 'fuzzy' }

-- swap file
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.local/state/nvim/undo")
