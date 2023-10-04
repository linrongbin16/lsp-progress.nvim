# lsp-progress.nvim

<p align="center">
<a href="https://github.com/neovim/neovim/releases/v0.6.0"><img alt="Neovim-v0.6.0" src="https://img.shields.io/badge/Neovim-v0.6.0-blueviolet.svg?logo=Neovim&logoColor=green" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/search?l=lua"><img alt="Top Language" src="https://img.shields.io/github/languages/top/linrongbin16/lsp-progress.nvim?label=Lua&logo=lua&logoColor=darkblue" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/linrongbin16/lsp-progress.nvim?logo=GNU&label=License" /></a>
<a href="https://github.com/linrongbin16/lsp-progress.nvim/actions/workflows/ci.yml"><img alt="ci.yml" src="https://img.shields.io/github/actions/workflow/status/linrongbin16/lsp-progress.nvim/ci.yml?logo=GitHub&label=CI" /></a>
</p>

A performant lsp progress status for Neovim.

https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/a96d8ad8-3366-4895-8300-6903479b9b60

Table of contents:

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

### [lazy.nvim](https://github.com/folke/lazy.nvim)

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

For complete configurations and defaults, please check [defaults.lua](https://github.com/linrongbin16/lsp-progress.nvim/blob/main/lua/lsp-progress/defaults.lua).

https://github.com/linrongbin16/lsp-progress.nvim/blob/6cca236f9d198907355d45d87008cc009e69cb4c/lua/lsp-progress/defaults.lua

https://github.com/linrongbin16/lsp-progress.nvim/blob/6cca236f9d198907355d45d87008cc009e69cb4c/lua/lsp-progress/defaults.lua#L3

For how to configure the permanent ` LSP` icon, please see [Permanent LSP icon](https://github.com/linrongbin16/lsp-progress.nvim/wiki/Advanced-Configuration#permanent-lsp-icon).

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
