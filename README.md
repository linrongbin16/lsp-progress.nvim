# lsp-progress.nvim

<p align="center">
<a href="https://github.com/neovim/neovim/releases/v0.6.0"><img alt="Neovim-v0.6.0" src="https://img.shields.io/badge/Neovim-v0.6.0-blueviolet.svg?logo=Neovim&logoColor=green" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/search?l=lua"><img alt="Top Language" src="https://img.shields.io/github/languages/top/linrongbin16/lsp-progress.nvim?label=Lua&logo=lua&logoColor=darkblue" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/linrongbin16/lsp-progress.nvim?logo=GNU&label=License" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/lsp-progress.nvim/ci.yml?logo=GitHub&label=Luacheck" /></a>
<a href="https://app.codecov.io/github/linrongbin16/lsp-progress.nvim"><img alt="codecov" src="https://img.shields.io/codecov/c/github/linrongbin16/lsp-progress.nvim?logo=codecov&logoColor=magenta&label=Codecov" /></a>
</p>

A performant lsp progress status for Neovim.

<!-- <https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/a96d8ad8-3366-4895-8300-6903479b9b60> -->

- Default

  https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/33c3366f-1f20-477c-9fac-6802e80eba02

- Always show LSP client names

  https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/04dc744a-90ff-48af-b6b5-2f42cc814c3e

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



## Table of contents

- [Performance](#performance)
- [Requirement](#requirement)
- [Install](#install)
  - [packer.nvim](#packernvim)
  - [lazy.nvim](#lazynvim)
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

- Neovim version &ge; 0.6.0.
- [Nerd fonts](https://www.nerdfonts.com/) for icons.

## Install

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- lua
return require('packer').startup(function(use)

  use {'nvim-tree/nvim-web-devicons'},
  use {
    'linrongbin16/lsp-progress.nvim',
    config = function()
      require('lsp-progress').setup()
    end
  }

  -- integrate with lualine
  use {
    'nvim-lualine/lualine.nvim',
    config = ...,
  }

end)
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- lua
require("lazy").setup({

  {
    'linrongbin16/lsp-progress.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lsp-progress').setup()
    end
  }

  -- integrate with lualine
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'linrongbin16/lsp-progress.nvim',
    },
    config = ...
  },

})
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
" vim
call plug#begin()

Plug 'nvim-tree/nvim-web-devicons'
Plug 'linrongbin16/lsp-progress.nvim'

" integrate with lualine
Plug 'nvim-lualine/lualine.nvim'

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

## Configuration

To configure options, please use:

```lua
require('lsp-progress').setup(option)
```

The `option` is an optional lua table that override the default options.

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
