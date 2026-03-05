-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Leader key (must be before lazy)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- LazyVim setup
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Catppuccin Mocha theme
    {
      "catppuccin/nvim",
      name = "catppuccin",
      lazy = false,
      priority = 1000,
      opts = {
        flavour = "mocha",
        transparent_background = true,
        integrations = {
          cmp = true,
          gitsigns = true,
          treesitter = true,
          notify = true,
          mini = { enabled = true },
          native_lsp = { enabled = true },
          telescope = { enabled = true },
          which_key = true,
        },
      },
    },
    -- Set colorscheme
    {
      "LazyVim/LazyVim",
      opts = { colorscheme = "catppuccin" },
    },
    -- Language support extras
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    -- Local plugins (your overrides go here)
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  checker = { enabled = true },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
