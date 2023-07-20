# lsp-progress.nvim

A performant lsp progress status for Neovim.

https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/a96d8ad8-3366-4895-8300-6903479b9b60

Table of contents:

- [Performance](#performance)
- [Requirement](#requirement)
- [Install](#install)
  - [packer](#packer)
  - [lazy](#lazy)
  - [vim-plug](#vim-plug)
- [Usage](#usage)
  - [Statusline Integration](#statusline-integration)
- [Configuration](#configuration)
- [Credit](#credit)
- [Contribute](#contribute)

## Performance

I use a 2-layer map to cache all lsp progress messages, thus transforming the
**O(n \* m)** time complexity calculation to almost **O(1)**.

> **n** is active lsp clients count, **m** is token count of each lsp client.

For more details, please see [Design & Technics](https://github.com/linrongbin16/lsp-progress.nvim/wiki/Design-&-Technics).

## Requirement

- Neovim version &ge; 0.8.
- [Nerd fonts](https://www.nerdfonts.com/) for icons.

## Install

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
-- lua
-- integrate with lualine
use {
  'nvim-lualine/lualine.nvim',
  requires = {
    'nvim-tree/nvim-web-devicons'
    'linrongbin16/lsp-progress.nvim',
  },
  config = ...,
}
use {
  'linrongbin16/lsp-progress.nvim',
  requires = {'nvim-tree/nvim-web-devicons'},
  config = function()
    require('lsp-progress').setup()
  end
}
```

### [lazy](https://github.com/folke/lazy.nvim)

```lua
-- lua
{
  -- integrate with lualine
  'nvim-lualine/lualine.nvim',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'linrongbin16/lsp-progress.nvim',
  },
  config = ...
},
{
  'linrongbin16/lsp-progress.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('lsp-progress').setup()
  end
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
" vim

call plug#begin()

Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-lualine/lualine.nvim'
Plug 'linrongbin16/lsp-progress.nvim'

call plug#end()

lua require('lsp-progress').setup()
```

## Usage

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

  The fields share the same schema with `setup(option)` (see [Configuration](#configuration))
  to provide more dynamic abilities.

### Statusline Integration

```lua
require("lualine").setup({
    sections = {
        lualine_a = { "mode" },
        lualine_b = { "filename" },
        lualine_c = {
            -- invoke `progress` here.
            "require('lsp-progress').progress()",
        },
        ...
    }
})

-- listen lsp-progress event and refresh lualine
vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
vim.api.nvim_create_autocmd("User LspProgressStatusUpdated", {
    group = "lualine_augroup",
    callback = require("lualine").refresh,
})
```

## Configuration

```lua
require('lsp-progress').setup({
    -- Regular internal update time.
    --
    -- Emit user event to update the lsp progress status, even there's no new
    -- message.
    --
    --- @type integer
    regular_internal_update_time = 1000,

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

For more advanced configurations, please see [Advanced Configuration](https://github.com/linrongbin16/lsp-progress.nvim/wiki/Advanced-Configuration).

## Credit

- [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim): Utility
  functions for getting diagnostic status and progress messages from LSP servers,
  for use in the Neovim statusline.
- [fidget.nvim](https://github.com/j-hui/fidget.nvim): Standalone UI for
  nvim-lsp progress.

## Contribute

Please open [issue](https://github.com/linrongbin16/lsp-progress.nvim/issues)/[PR](https://github.com/linrongbin16/lsp-progress.nvim/pulls) for anything about lsp-progress.nvim.

Like lsp-progress.nvim? Consider

[![buymeacoffee](https://img.shields.io/badge/-Buy%20Me%20a%20Coffee-ff5f5f?logo=ko-fi&logoColor=white)](https://www.buymeacoffee.com/linrongbin16)
[![Wechat Pay](https://img.shields.io/badge/-Tip%20Me%20on%20WeChat-brightgreen?logo=wechat&logoColor=white)](https://github.com/linrongbin16/lin.nvim/wiki/Sponsor)
[![Alipay](https://img.shields.io/badge/-Tip%20Me%20on%20Alipay-blue?logo=alipay&logoColor=white)](https://github.com/linrongbin16/lin.nvim/wiki/Sponsor)
