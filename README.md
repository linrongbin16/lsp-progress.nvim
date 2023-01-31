# lsp-progress.nvim

Another lsp progress status for Neovim.

![demo](https://user-images.githubusercontent.com/6496887/215637132-65e27eac-df71-4d17-9365-b516d6536ece.jpg)
![demo-format](https://user-images.githubusercontent.com/6496887/215700315-9d205333-b0e8-4630-9afd-67e2a1c6e3ae.jpg)

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and [fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about lsp progress I learned and copied source code is from them.**

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

-- listen to user event and trigger lualine refresh
vim.cmd([[
augroup lualine_refresh_augroup
    autocmd!
    autocmd User LspProgressStatusUpdate lua require("lualine").refresh()
augroup END
]])
```

# Option

```lua
require('lsp-progress').setup({
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }, -- animation string array
    update_time = 200, -- interval update time in milliseconds
    sign = " LSP", -- icon: nf-fa-gear \uf013
    seperator = " ", -- seperator when multiple lsp messages
    decay = 1000, -- last progress message is cached in decay time in milliseconds,
                  -- since progress message could appear and disappear in an instant
    event = "LspProgressStatusUpdate", -- user event name
    debug = false, -- set true to enable logging file
    console_log = true, -- write log to vim console
    file_log = false, -- write log to file
    file_name = "lsp-progress.log", -- log file name, only if file_log=true.
})
```
