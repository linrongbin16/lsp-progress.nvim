# lsp-progress.nvim

Another simple LSP progress status plugin for neovim statusline integration.

<p align="center">
  <img
    alt="demo.jpg"
    src="https://raw.githubusercontent.com/linrongbin16/lsp-progress.nvim/main/demo.jpg"
    width="60%"
  />
</p>

**Thanks to [lsp-status.nvim](https://github.com/nvim-lua/lsp-status.nvim) and [fidget.nvim](https://github.com/j-hui/fidget.nvim), everything about LSP progress I learned and copied source code is from them.**

# Install

## Lazy

```lua
{
    'nvim-lualine/lualine.nvim', -- integrate with lualine
    event = { 'VimEnter' },
    dependencies = { 'nvim-tree/nvim-web-devicons', 'nvim-lua/lsp-status.nvim' },
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

- `require('lsp-progress).progress()`: get the progress message.
- `LspProgressStatusUpdate`: user event to trigger statusline refresh.

# Usage

## Lualine

```lua
require("lualine").setup({
    sections = {
		lualine_a = { "mode" },
		lualine_b = { "filename" },
		lualine_c = {
            require("lsp-progress").progress, -- lualine will invoke this function to get lsp progress message.
        },
    }
})
```

# Config

```lua
require('lsp-progress').setup({
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }, -- string array that animated the status
    update_time = 125, -- interval message update time in milliseconds
    sign = " [LSP]", -- icon: nf-fa-gear \uf013
    decay = 1000, -- decay time after message gone in milliseconds
})
```
