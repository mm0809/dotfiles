-- Bootstrap lazy.nvim
if vim.env.GITHUB_CI then
    vim.notify("GITHUB_CI environment variable is set.", vim.log.levels.INFO)
    vim.o.loadplugins = true
    vim.env.LAZY_STDPATH = "data"
    load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()
else
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
      if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
          { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
          { out, "WarningMsg" },
          { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
      end
    end
    vim.opt.rtp:prepend(lazypath)
end

require("lazy").setup({
    {
        "rebelot/kanagawa.nvim",
        config = function()
            require("kanagawa").setup({
                keywordStyle = { bold = true, italic = false},
                statementStyle = { bold = true },
            })
            vim.cmd.colorscheme("kanagawa-wave")
        end,
    },
})
