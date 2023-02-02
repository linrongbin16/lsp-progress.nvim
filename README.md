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
    -- spin icon array
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

    -- spin update rate in milliseconds
    update_time = 200,

    -- if there's any lsp server active on current buffer
    -- icon: nf-fa-gear \uf013
    sign = " LSP",

    -- seperate multiple messages in one statusline
    seperator = " ",

    -- last message is cached in decay time in milliseconds
    -- since some messages could appear and disappear in an instant
    decay = 1000,

    -- user event name
    event = "LspProgressStatusUpdated",

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

## Design Pattern

Implement with a producer/consumer pattern:

- Producer: progress handler is registered to `$/progress`, callback when lsp status updated. Then update status data and emit event `LspProgressStatusUpdated`.
- Consumer: statusline listens and consumes the event, get the latest status data, format and print to statusline.

## Data Structure

A buffer could have multiple active lsp clients. Each client could have multiple messages. Every message should be a data series over time, from beginning to end.

There're two hash maps based on this situation:

```
                    clients:
                    /      \
            (client_id1)  (client_id2)
                  /          \
                tasks        ...
                /   \
          (token1)  (token2)
              /       \
           task1      task2
```

1. Clients: a hash map that mapping from lsp client id (`client_id`) to all its series messages, here we call them tasks.
2. Tasks: a hash map that mapping from a message token (`token`) to a unique message.

## Message State

Every message should have 3 states (belong to same token):

- begin
- report
- end

## Animation Control

### Fixed Spin Rate

The `$/progress` doesn't guarantee when to update the message, but we want a stable animation that keeps spinning. A background job should be created and scheduled at a fixed time, and spin the icon. Use Neovim's `vim.defer_fn` API and Lua's closures.

This also means there's a new producer who emit event: whenever spins(background job schedules), emit an event to let the statusline update its animation.

### Decay Last Message

Lsp status could be really fast(appears and disappears in an instant) even user cannot see it clearly. A decay time should be added to cache the last message for a while.

And still, in decay time, the animation still needs to keep spinning!
