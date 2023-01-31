# lsp-progress.nvim

Simple LSP progress status plugin for neovim.

![demo](https://user-images.githubusercontent.com/6496887/215637132-65e27eac-df71-4d17-9365-b516d6536ece.jpg)

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and [fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about LSP progress I learned and copied source code is from them.**

# Install

## Lazy

```lua
{
    'nvim-lualine/lualine.nvim', -- integrate with lualine
    event = { 'VimEnter' },
    dependencies = { 'nvim-tree/nvim-web-devicons', 'linrongbin16/lsp-progress.nvim' },
    config = function()
        ...
    end
},
{
    'linrongbin16/lsp-progress.nvim',
    branch = 'main',
    event = { 'VimEnter' },
    config = function()
        require('lsp-progress').setup({})
    end
}
```

# API

- `require('lsp-progress).progress()`: get the progress status.
- `LspProgressStatusUpdate`: user event to notify new status, listen and trigger statusline refresh.

# Config

## Lualine

```lua
require("lualine").setup({
    sections = {
		lualine_a = { "mode" },
		lualine_b = { "filename" },
		lualine_c = {
            require("lsp-progress").progress, -- lualine will invoke this function to get lsp progress message.
        },
        ...
    }
})

vim.cmd([[
augroup lualine_refresh_augroup
    autocmd!
    autocmd User LspProgressStatusUpdate lua require("lualine").refresh() -- listen to user event and trigger refresh
augroup END
]])
```

# Option

```lua
require('lsp-progress').setup({
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }, -- animation string array
    update_time = 125, -- interval update time in milliseconds
    sign = " [LSP]", -- icon: nf-fa-gear \uf013
    seperator = " ┆ ", -- seperator when multiple lsp messages
    decay = 500, -- last progress message is cached in decay time in milliseconds,
                 -- since progress message could appear and disappear in an instant
    event = "LspProgressStatusUpdate", -- default user event name
})
```
