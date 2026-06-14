vim.g.mapleader = " "

vim.keymap.set('i', 'jj', '<Esc>')
vim.keymap.set('n', 'gl', '<cmd>lua vim.diagnostic.open_float()<cr>')

-- delete or paste without yanking
vim.keymap.set('v', '<leader>d', '"_d')
vim.keymap.set('v', '<leader>p', '"_dP')

---------- FZF ----------
-- Open file
vim.keymap.set('n', '<C-p>', '<cmd>FZF<CR>')

-- Open file in buffer
vim.keymap.set('n', '<leader><C-p>', '<cmd>Buffers<CR>')

-- Ripgrep current word
vim.keymap.set('n', '<leader>rg', function()
    local word = vim.fn.expand('<cword>')
    vim.cmd('Rg ' .. word)
end)

---------- Terminal mode ----------
-- Map Esc to exit terminal mode
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { silent = true })

-- Map Ctrl+W + h/j/k/l to switch windows while in terminal mode
vim.keymap.set('t', '<C-w>h', '<C-\\><C-n><C-w>h', { silent = true })
vim.keymap.set('t', '<C-w>j', '<C-\\><C-n><C-w>j', { silent = true })
vim.keymap.set('t', '<C-w>k', '<C-\\><C-n><C-w>k', { silent = true })
vim.keymap.set('t', '<C-w>l', '<C-\\><C-n><C-w>l', { silent = true })


---------- Tab ----------
-- vim.keymap.set('n', '<Tab>', '<cmd>tabnext<cr>') Ths conflict with C-i
vim.keymap.set('n', '<S-Tab>', '<cmd>tabprevious<cr>')


---------- Quickfix list ----------
vim.keymap.set('n', '<C-j>', '<cmd>cnext<cr>')
vim.keymap.set('n', '<C-k>', '<cmd>cprev<cr>')
