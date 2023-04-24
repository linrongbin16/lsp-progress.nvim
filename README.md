# lsp-progress.nvim

A performant lsp progress status for Neovim.

![demo](https://user-images.githubusercontent.com/6496887/215637132-65e27eac-df71-4d17-9365-b516d6536ece.jpg)
![demo-format](https://user-images.githubusercontent.com/6496887/215700315-9d205333-b0e8-4630-9afd-67e2a1c6e3ae.jpg)

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and
[fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about lsp
progress I learned and copied source code is from them.**

## Requirement

- Neovim version &ge; 0.8.
- [Nerd fonts](https://www.nerdfonts.com/) for icons.

## Install

### Lazy

```lua
{
    -- integrate with lualine
    'nvim-lualine/lualine.nvim',
    event = { 'VimEnter' },
    dependencies = {
        'nvim-tree/nvim-web-devicons',
        'linrongbin16/lsp-progress.nvim',
    },
    config = function()
        ...
    end
},
{
    'linrongbin16/lsp-progress.nvim',
    event = { 'VimEnter' },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
        require('lsp-progress').setup()
    end
}
```

## API

- `LspProgressStatusUpdated`: user event to notify new status, and trigger statusline refresh.
- `require('lsp-progress').progress(option)`: get lsp progress status, parameter `option` is an optional lua table:

```lua
require('lsp-progress').progress({
    format = ...,
    max_size = ...,
})
```

They share the same fields with `setup(option)` (see [Configuration](#configuration)) to provide more dynamic abilities.

### Statusline Integration

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

## Configuration

```lua
require('lsp-progress').setup({
    -- Spinning icons.
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

    -- Spinning update time in milliseconds.
    spin_update_time = 200,

    -- Last message cached decay time in milliseconds.
    --
    -- Message could be really fast(appear and disappear in an
    -- instant) that user cannot even see it, thus we cache the last message
    -- for a while for user view.
    decay = 1000,

    -- User event name.
    event = "LspProgressStatusUpdated",

    -- Event update time limit in milliseconds.
    --
    -- Sometimes progress handler could emit many events in an instant, while
    -- refreshing statusline cause too heavy synchronized IO, so we limit the
    -- event rate to reduce this cost.
    event_update_time_limit = 100,

    --- Max progress string length, by default -1 is unlimit.
    max_size = -1,

    -- Format series message.
    --
    -- By default it looks like: `formatting isort (100%) - done`.
    --
    -- @param title      Message title.
    -- @param message    Message body.
    -- @param percentage Progress in percentage numbers: [0%-100%].
    -- @param done       Indicate if this message is the last one in progress.
    -- @return           A nil|string|table value. The returned value will be
    --                   passed to function `client_format` as one of the
    --                   `series_messages` array, or ignored if return nil.
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

    -- Format client message.
    --
    -- By default it looks like:
    -- `[null-ls] ⣷ formatting isort (100%) - done, formatting black (50%)`.
    --
    -- @param client_name     Client name.
    -- @param spinner         Spinner icon.
    -- @param series_messages Series messages array.
    -- @return                A nil|string|table value. The returned value will
    --                        be passed to function `format` as one of the
    --                        `client_messages` array, or ignored if return nil.
    client_format = function(client_name, spinner, series_messages)
        return #series_messages > 0
                and ("[" .. client_name .. "] " .. spinner .. " " .. table.concat(
                    series_messages,
                    ", "
                ))
            or nil
    end,

    -- Format (final) message.
    --
    -- By default it looks like:
    -- ` LSP [null-ls] ⣷ formatting isort (100%) - done, formatting black (50%)`
    --
    -- @param client_messages Client messages array.
    -- @return                A nil|string|table value. The returned value will be
    --                        returned from `progress` API.
    format = function(client_messages)
        local sign = " LSP" -- nf-fa-gear \uf013
        return #client_messages > 0
                and (sign .. " " .. table.concat(client_messages, " "))
            or sign
    end,

    --- Enable debug.
    debug = false,

    --- Print log to console(command line).
    console_log = true,

    --- Print log to file.
    file_log = false,

    -- Log file to write, work with `file_log=true`.
    -- For Windows: `$env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log`.
    -- For *NIX: `~/.local/share/nvim/lsp-progress.log`.
    file_log_name = "lsp-progress.log",
})
```

## Notes

Please checkout [notes](/doc/notes.md).
