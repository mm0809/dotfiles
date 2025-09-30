-- LSP: config for clangd
vim.lsp.config['clangd'] = {
    -- Command and arguments to start the server.
    cmd = { clangd_path },
    -- Filetypes to automatically attach to.
    filetypes = { 'cpp', 'c', 'inc' },
    -- Sets the "workspace" to the directory where any of these files is found.
    -- Files that share a root directory will reuse the LSP server connection.
    -- Nested lists indicate equal priority, see |vim.lsp.Config|.
    root_markers = { 'compile_commands.json', '.git' },
}
vim.lsp.enable('clangd')

vim.lsp.config['pyright'] = {
    -- Command and arguments to start the server.
    cmd = { 'pyright-langserver', '--stdio' },
    -- Filetypes to automatically attach to.
    filetypes = { 'python' },
    -- Sets the "workspace" to the directory where any of these files is found.
    -- Files that share a root directory will reuse the LSP server connection.
    -- Nested lists indicate equal priority, see |vim.lsp.Config|.
    root_markers = { 'requirements.txt', 'setup.py', '.git' },
    settings = {
        python = {
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = 'openFilesOnly',
            },
        },
    },
}

vim.lsp.enable('pyright')
vim.lsp.enable('clangd')

-- LSP: keybindings
vim.api.nvim_create_autocmd('LspAttach', {
    desc = "Lsp keybindings",
    callback =function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client:supports_method('textDocument/completion') then
            vim.print("hellpo")
            vim.lsp.completion.enable(true, client.id, event.buf, {autotrigger = true})
        end

        local opts = {buffer = event.buf}
        vim.keymap.set('i', '<C-Space>', '<C-x><C-o>', opts)
        vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
        vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
        vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
        vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
        vim.keymap.set('n', 'gt', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
        vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
        vim.keymap.set('i', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
        -- vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
        -- vim.keymap.set({'n', 'x'}, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
        -- vim.keymap.set('n', '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
    end,
})

-- LSP: set diagnostic messages
vim.diagnostic.config({ 
    virtual_text = false,
    update_in_insert = false
})


-- LSP: Tab completion
vim.opt.shortmess:append('c')

local function tab_complete()
  if vim.fn.pumvisible() == 1 then
    -- navigate to next item in completion menu
    return '<Down>'
  end

  local c = vim.fn.col('.') - 1
  local is_whitespace = c == 0 or vim.fn.getline('.'):sub(c, c):match('%s')

  if is_whitespace then
    -- insert tab
    return '<Tab>'
  end

  local lsp_completion = vim.bo.omnifunc == 'v:lua.vim.lsp.omnifunc'

  if lsp_completion then
    -- trigger lsp code completion
    return '<C-x><C-o>'
  end

  -- suggest words in current buffer
  return '<C-x><C-n>'
end

local function tab_prev()
  if vim.fn.pumvisible() == 1 then
    -- navigate to previous item in completion menu
    return '<Up>'
  end

  -- insert tab
  return '<Tab>'
end

vim.keymap.set('i', '<Tab>', tab_complete, {expr = true})
vim.keymap.set('i', '<S-Tab>', tab_prev, {expr = true})
