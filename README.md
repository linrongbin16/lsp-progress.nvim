# lsp-progress.nvim

Another lsp progress status for Neovim.

![demo](https://user-images.githubusercontent.com/6496887/215637132-65e27eac-df71-4d17-9365-b516d6536ece.jpg)
![demo-format](https://user-images.githubusercontent.com/6496887/215700315-9d205333-b0e8-4630-9afd-67e2a1c6e3ae.jpg)

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and [fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about lsp progress I learned and copied source code is from them.**

# Requirement

Neovim version &ge; 0.8.

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
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
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
augroup lualine_augroup
    autocmd!
    autocmd User LspProgressStatusUpdated lua require("lualine").refresh()
augroup END
]])
```

# Option

```lua
require('lsp-progress').setup({
    -- @description
    --   Spinning icon array.
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

    -- @description
    --   Spinning update time in milliseconds.
    spin_update_time = 200,

    -- @deprecated
    -- @description
    --   Indicate if there's any lsp server active on current buffer.
    --   Icon: nf-fa-gear(\uf013).
    sign = " LSP",

    -- @deprecated
    -- @description
    --   Seperate multiple messages in one statusline
    seperator = " ",

    -- @description
    --   Last message is cached in decay time in milliseconds.
    --   Messages could be really fast, appear and disappear in an instant,
    --   so here cache the last message for a while for user view.
    decay = 1000,

    -- @description
    --   User event name.
    event = "LspProgressStatusUpdated",

    -- @description
    --   Event update time limit in milliseconds.
    --   Sometimes progress handler could emit many events in an instant,
    --   while refreshing statusline cause too heavy synchronized IO,
    --   so limit the event emit rate to reduce the cost.
    event_update_time_limit = 125,

    -- @description
    --   Max progress string length, by default -1 is unlimit.
    max_size = -1,

    -- @description
    --   Format series message.
    -- @param title      Lsp progress message title
    -- @param message    Lsp progress message body
    -- @param percentage Lsp progress message in number 0%-100%
    -- @param done       Indicate if this message is the last one in progress
    -- @return           Return type: nil|string|table
    --                   This message will be passed to `client_format` as
    --                   one of the `series_messages` array. Or ignored if
    --                   return nil.
    series_format = function(title, message, percentage, done)
        local builder = {}
        local has_title = false
        local has_message = false
        if title and title ~= "" then
            table.insert(builder, title)
            has_title = true
        end
        if message and message ~= "" then
            table.insert(builder, message)
            has_message = true
        end
        if percentage and (has_title or has_message) then
            table.insert(builder, string.format("(%.0f%%%%)", percentage))
        end
        if done and (has_title or has_message) then
            table.insert(builder, "- done")
        end
        return table.concat(builder, " ")
    end,

    -- @description
    --   Format client message.
    -- @param client_name     Lsp client(server) name.
    -- @param spinner         Lsp spinner icon.
    -- @param series_messages Formatted series message array in this client.
    -- @return                Return type: nil|string|table
    --                        This message will be passed to `format` as one
    --                        of the `client_messages` array. Or ignored if
    --                        return nil.
    client_format = function(client_name, spinner, series_messages)
        return #series_messages > 0
                and ("[" .. client_name .. "] " .. spinner .. " " .. table.concat(series_messages, ", "))
            or nil
    end,

    -- @description
    --   Format (final) message.
    -- @param client_messages Formatted client message array.
    -- @return                Return type: nil|string
    --                        This message will return to `progress` API.
    format = function(client_messages)
        local sign = " LSP" -- nf-fa-gear \uf013
        return #client_messages > 0 and (sign .. " " .. table.concat(client_messages, " ")) or sign
    end,

    -- @description
    --   Enable debug.
    debug = false,

    -- @description
    --   Print log to console.
    console_log = true,

    -- @description
    --   Print log to file.
    file_log = false,

    -- @description
    --   Log file to write, work with `file_log=true`.
    --   For Windows: `$env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log`.
    --   For *NIX: `~/.local/share/nvim/lsp-progress.log`.
    file_log_name = "lsp-progress.log",
})
```

# Notes

See: [doc/notes.md](doc/notes.md)
