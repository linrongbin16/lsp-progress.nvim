set nocompatible
set number

lua << EOF
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = function()
      require('telescope').setup({})
    end
  },

  {
    'linrongbin16/lsp-progress.nvim',
    dev=true,
    dir="~/github/linrongbin16/lsp-progress.nvim",
    config = function()
    require('lsp-progress').setup({debug=true, file_log=true,console_log=false})
    end,
  },
},
{})
EOF
