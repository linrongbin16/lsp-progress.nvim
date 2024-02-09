<!-- markdownlint-disable MD001 MD013 MD034 MD033 MD051 -->

# lsp-progress.nvim

<p>
<a href="https://github.com/neovim/neovim/releases/v0.6.0"><img alt="Neovim" src="https://img.shields.io/badge/require-0.6%2B-blue" /></a>
<a href="https://luarocks.org/modules/linrongbin16/lsp-progress.nvim"><img alt="luarocks" src="https://img.shields.io/luarocks/v/linrongbin16/lsp-progress.nvim" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/lsp-progress.nvim/ci.yml?label=ci" /></a>
<a href="https://app.codecov.io/github/linrongbin16/lsp-progress.nvim"><img alt="codecov" src="https://img.shields.io/codecov/c/github/linrongbin16/lsp-progress.nvim?logo=codecov&logoColor=F01F7A&label=Codecov" /></a>
</p>

<p align="center"><i> A performant lsp progress status for Neovim. </i></p>

<!-- https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/a0436100-d35c-48a1-a9c4-4346b09d6b25 -->

![default](https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/e089234b-d465-45ae-840f-72a57b846b0d)

<details>
<summary><i>Click here to see how to configure</i></summary>

```lua
require("lsp-progress").setup()
```

</details>

<!-- https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/84f17744-9404-4a7b-bbdf-aac5babc0ed3 -->

![client-names](https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/01dac7a0-678a-421d-a243-9dba2576b15b)

<details>
<summary><i>Click here to see how to configure</i></summary>

```lua
require("lsp-progress").setup({
  client_format = function(client_name, spinner, series_messages)
    if #series_messages == 0 then
      return nil
    end
    return {
      name = client_name,
      body = spinner .. " " .. table.concat(series_messages, ", "),
    }
  end,
  format = function(client_messages)
    --- @param name string
    --- @param msg string?
    --- @return string
    local function stringify(name, msg)
      return msg and string.format("%s %s", name, msg) or name
    end

    local sign = "" -- nf-fa-gear \uf013
    local lsp_clients = vim.lsp.get_active_clients()
    local messages_map = {}
    for _, climsg in ipairs(client_messages) do
      messages_map[climsg.name] = climsg.body
    end

    if #lsp_clients > 0 then
      table.sort(lsp_clients, function(a, b)
        return a.name < b.name
      end)
      local builder = {}
      for _, cli in ipairs(lsp_clients) do
        if
          type(cli) == "table"
          and type(cli.name) == "string"
          and string.len(cli.name) > 0
        then
          if messages_map[cli.name] then
            table.insert(builder, stringify(cli.name, messages_map[cli.name]))
          else
            table.insert(builder, stringify(cli.name))
          end
        end
      end
      if #builder > 0 then
        return sign .. " " .. table.concat(builder, ", ")
      end
    end
    return ""
  end,
})
```

</details>

<!-- https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/9436de63-ea94-4ada-adb7-3812681a5106 -->

![green-check](https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/2666b105-4939-4985-8b5e-74bc43e5615c)

<details>
<summary><i>Click here to see how to configure</i></summary>

```lua
require("lsp-progress").setup({
  decay = 1200,
  series_format = function(title, message, percentage, done)
    local builder = {}
    local has_title = false
    local has_message = false
    if type(title) == "string" and string.len(title) > 0 then
      local escaped_title = title:gsub("%%", "%%%%")
      table.insert(builder, escaped_title)
      has_title = true
    end
    if type(message) == "string" and string.len(message) > 0 then
      local escaped_message = message:gsub("%%", "%%%%")
      table.insert(builder, escaped_message)
      has_message = true
    end
    if percentage and (has_title or has_message) then
      table.insert(builder, string.format("(%.0f%%%%)", percentage))
    end
    return { msg = table.concat(builder, " "), done = done }
  end,
  client_format = function(client_name, spinner, series_messages)
    if #series_messages == 0 then
      return nil
    end
    local builder = {}
    local done = true
    for _, series in ipairs(series_messages) do
      if not series.done then
        done = false
      end
      table.insert(builder, series.msg)
    end
    if done then
      spinner = "✓" -- replace your check mark
    end
    return "["
      .. client_name
      .. "] "
      .. spinner
      .. " "
      .. table.concat(builder, ", ")
  end,
})
```

</details>

## Table of contents

- [Performance](#performance)
- [Requirement](#requirement)
- [Install](#install)
- [Usage](#usage)
- [Integration](#integration)
  - [lualine.nvim](#lualinenvim)
  - [heirline.nvim](#heirlinenvim)
- [Configuration](#configuration)
- [Credit](#credit)
- [Contribute](#contribute)

## Performance

I use a 2-layer map to cache all lsp progress messages, thus transforming the
**O(n \* m)** time complexity calculation to almost **O(1)**.

> **n** is active lsp clients count, **m** is token count of each lsp client.

For more details, please see [Design & Technics](https://github.com/linrongbin16/lsp-progress.nvim/wiki/Design-&-Technics).

## Requirement

- Neovim &ge; 0.6.0.
- [Nerd fonts](https://www.nerdfonts.com/) for icons.

## Install

<details>
<summary><b>With <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></b></summary>

```lua
-- lua
return require('packer').startup(function(use)
  use {
    'linrongbin16/lsp-progress.nvim',
    config = function()
      require('lsp-progress').setup()
    end
  }
end)
```

</details>

<details>
<summary><b>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></b></summary>

```lua
-- lua
require("lazy").setup({
  {
    'linrongbin16/lsp-progress.nvim',
    config = function()
      require('lsp-progress').setup()
    end
  }
})
```

</details>

<details>
<summary><b>With <a href="https://github.com/junegunn/vim-plug">vim-plug</a></b></summary>

```vim
" vim
call plug#begin()

Plug 'linrongbin16/lsp-progress.nvim'

call plug#end()

lua require('lsp-progress').setup()
```

</details>

## Usage

- `LspProgressStatusUpdated`: user event to notify new status, and trigger statusline
  refresh.
- `require('lsp-progress').progress(opts)`: get lsp progress status, parameter
  `opts` is an optional lua table:

  ```lua
  require('lsp-progress').progress({
      format = ...,
      max_size = ...,
  })
  ```

  The fields are the same value passing to `setup` (see [Configuration](#configuration))
  to provide more dynamic abilities.

## Integration

### [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)

```lua
require("lualine").setup({
  sections = {
    lualine_a = { ... },
    lualine_b = { ... },
    lualine_c = {
      -- invoke `progress` here.
      require('lsp-progress').progress,
    },
    ...
  }
})

-- listen lsp-progress event and refresh lualine
vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = "lualine_augroup",
  pattern = "LspProgressStatusUpdated",
  callback = require("lualine").refresh,
})
```

### [heirline.nvim](https://github.com/rebelot/heirline.nvim)

```lua
local LspProgress = {
  provider = require('lsp-progress').progress,
  update = {
    'User',
    pattern = 'LspProgressStatusUpdated',
    callback = vim.schedule_wrap(function()
      vim.cmd('redrawstatus')
    end),
  }
}

local StatusLine = {
  -- Other StatusLine components
  { ... },
  { ... },

  -- Lsp progress status component here
  LspProgress
}

require('heirline').setup({
  statusline = StatusLine
})
```

## Configuration

To configure options, please use:

```lua
require('lsp-progress').setup(opts)
```

The `opts` is an optional lua table that overwrite the default options.

For complete options and defaults, please check [defaults.lua](https://github.com/linrongbin16/lsp-progress.nvim/blob/main/lua/lsp-progress/defaults.lua).

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

[![Github Sponsor](https://img.shields.io/badge/-Sponsor%20Me%20on%20Github-magenta?logo=github&logoColor=white)](https://github.com/sponsors/linrongbin16)
[![Wechat Pay](https://img.shields.io/badge/-Tip%20Me%20on%20WeChat-brightgreen?logo=wechat&logoColor=white)](https://github.com/linrongbin16/lin.nvim/wiki/Sponsor)
[![Alipay](https://img.shields.io/badge/-Tip%20Me%20on%20Alipay-blue?logo=alipay&logoColor=white)](https://github.com/linrongbin16/lin.nvim/wiki/Sponsor)
