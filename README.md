# lsp-progress.nvim

Another lsp progress status for Neovim.

![demo](https://user-images.githubusercontent.com/6496887/215637132-65e27eac-df71-4d17-9365-b516d6536ece.jpg)
![demo-format](https://user-images.githubusercontent.com/6496887/215700315-9d205333-b0e8-4630-9afd-67e2a1c6e3ae.jpg)

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and [fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about lsp progress I learned and copied source code is from them.**

# Install

## Lazy

```lua
{
    -- integrate with lualine
    'nvim-lualine/lualine.nvim',
    event = { 'VimEnter' },
    dependencies = {
        'nvim-tree/nvim-web-devicons',
        'linrongbin16/lsp-progress.nvim'
    },
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
- `LspProgressStatusUpdated`: user event to notify new status, listen and trigger statusline refresh.

## Statusline Integration

```lua
require("lualine").setup({
    sections = {
		lualine_a = { "mode" },
		lualine_b = { "filename" },
		lualine_c = {
            -- invoke `progress` to get lsp progress status.
            require("lsp-progress").progress,
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
    -- spinning icon array
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

    -- spinning update time in milliseconds
    spin_update_time = 200,

    -- indicate if there's any lsp server active on current buffer
    -- icon: nf-fa-gear \uf013
    sign = " LSP",

    -- seperate multiple messages in one statusline
    seperator = " ",

    -- last message is cached in decay time in milliseconds
    -- messages could be really fast, appear and disappear in an instant
    decay = 1000,

    -- user event name
    event = "LspProgressStatusUpdated",

    -- event update time limit in milliseconds
    -- sometimes progress handler could emit many events, trigger statusline refresh too many
    event_update_time_limit = 125,

    -- max progress string length
    max_size = 120,

    -- if enable debug
    debug = false,

    -- if print log to console
    console_log = true,

    -- if print log to file
    file_log = false,

    -- logging file to write, only if file_log=true
    file_log_name = "lsp-progress.log",
})
```

# Notes

See: doc/notes.md
