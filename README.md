# lsp-progress.nvim

A performant lsp progress status for Neovim.

![demo](https://user-images.githubusercontent.com/6496887/215637132-65e27eac-df71-4d17-9365-b516d6536ece.jpg)
![demo-format](https://user-images.githubusercontent.com/6496887/215700315-9d205333-b0e8-4630-9afd-67e2a1c6e3ae.jpg)

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and
[fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about lsp
progress I learned and copied source code is from them.**

## Performance

I use a 2-layer map to cache all lsp progress messages, to transform the **O(n \* m)** time complexity calculation to less than **O(n)**.
Where **n** is active lsp clients count, **m** is token count of each lsp client.
Compared with [neovim#23958](https://github.com/neovim/neovim/pull/23958), it's much more performant.

For more details, please see: [notes](/doc/notes.md).

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

- `LspProgressStatusUpdated`: user event to notify new status, and trigger statusline
  refresh.
- `require('lsp-progress').progress(option)`: get lsp progress status, parameter
  `option` is an optional lua table:

   ```lua
   require('lsp-progress').progress({
       format = ...,
       max_size = ...,
   })
   ```

   They share the same fields with `setup(option)` (see [Configuration](#configuration))
   to provide more dynamic abilities.

### Statusline Integration

```lua
require("lualine").setup({
    sections = {
        lualine_a = { "mode" },
        lualine_b = { "filename" },
        lualine_c = {
            -- invoke `progress` here.
            require("lsp-progress").progress,
        },
        ...
    }
})

-- refresh lualine
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
    --
    --- @type string[]
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

    -- Spinning update time in milliseconds.
    --
    --- @type integer
    spin_update_time = 200,

    -- Last message cached decay time in milliseconds.
    --
    -- Message could be really fast(appear and disappear in an
    -- instant) that user cannot even see it, thus we cache the last message
    -- for a while for user view.
    --
    --- @type integer
    decay = 1000,

    -- User event name.
    --
    --- @type string
    event = "LspProgressStatusUpdated",

    -- Event update time limit in milliseconds.
    --
    -- Sometimes progress handler could emit many events in an instant, while
    -- refreshing statusline cause too heavy synchronized IO, so we limit the
    -- event rate to reduce this cost.
    --
    --- @type integer
    event_update_time_limit = 100,

    -- Max progress string length, by default -1 is unlimit.
    --
    --- @type integer
    max_size = -1,

    -- Format series message.
    --
    -- By default it looks like: `formatting isort (100%) - done`.
    --
    --- @param title string|nil
    ---     Message title.
    --- @param message string|nil
    ---     Message body.
    --- @param percentage number|nil
    ---     Progress in percentage numbers: 0-100.
    --- @param done boolean
    ---     Indicate whether this series is the last one in progress.
    --- @return nil|string|table messages
    ---     The returned value will be passed to function `client_format` as
    ---     one of the `series_messages` array, or ignored if return nil.
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
    --- @param client_name string
    ---     Client name.
    --- @param spinner string
    ---     Spinner icon.
    --- @param series_messages string[]|table[]
    ---     Messages array.
    --- @return nil|string|table messages
    ---     The returned value will be passed to function `format` as one of the
    ---     `client_messages` array, or ignored if return nil.
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
    --- @param client_messages string[]|table[]
    ---     Client messages array.
    --- @return nil|string message
    ---     The returned value will be returned from `progress` API.
    format = function(client_messages)
        local sign = " LSP" -- nf-fa-gear \uf013
        return #client_messages > 0
                and (sign .. " " .. table.concat(client_messages, " "))
            or sign
    end,

    -- Enable debug.
    --
    --- @type boolean
    debug = false,

    -- Print log to console(command line).
    --
    --- @type boolean
    console_log = true,

    -- Print log to file.
    --
    --- @type boolean
    file_log = false,

    -- Log file to write, work with `file_log=true`.
    --
    -- For Windows: `$env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log`.
    -- For *NIX: `~/.local/share/nvim/lsp-progress.log`.
    --
    --- @type string
    file_log_name = "lsp-progress.log",
})
```

### Advanced Configurations

1. Split the sign ` LSP` and messages:

```lua
-- lualine

local function LspSign()
    return require("lsp-progress").progress({
        format = function(messages)
            return " LSP"
        end,
    })
end

local function LspStatus()
    return require("lsp-progress").progress({
        format = function(messages)
            return #messages > 0 and table.concat(messages, " ") or ""
        end,
    })
end

require("lualine").setup({
    sections = {
        lualine_a = { "mode" },
        lualine_b = { "filename" },
        lualine_c = {
            LspSign, -- signs: ` LSP`
            LspStatus, -- messages: `[null-ls] ⣷ formatting isort (100%) - done`
        },
        ...
    }
})
```
