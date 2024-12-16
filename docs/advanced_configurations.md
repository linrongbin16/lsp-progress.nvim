# Advanced Configurations

## Show LSP Client Names

<video width="80%" controls>
  <source src="https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/7b959db9-f088-4879-b4c6-152f07a1955d" type="video/mp4">
</video>

Configurations:

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
                        table.insert(
                            builder,
                            stringify(cli.name, messages_map[cli.name])
                        )
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

## Show LSP Client Counts & Names

<video width="80%" controls>
  <source src="https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/73897c6b-2bb7-4103-b3c2-fd413e6b0d9b" type="video/mp4">
</video>

Configurations:

```lua
require("lsp-progress").setup()
```

```lua
return require("lsp-progress").progress({
    format = function(messages)
        local active_clients = vim.lsp.get_active_clients()
        local client_count = #active_clients
        if #messages > 0 then
            return " LSP:"
                .. client_count
                .. " "
                .. table.concat(messages, " ")
        end
        if #active_clients <= 0 then
            return " LSP:" .. client_count
        else
            local client_names = {}
            for i, client in ipairs(active_clients) do
                if client and client.name ~= "" then
                    table.insert(client_names, "[" .. client.name .. "]")
                    print(
                        "client[" .. i .. "]:" .. vim.inspect(client.name)
                    )
                end
            end
            return " LSP:"
                .. client_count
                .. " "
                .. table.concat(client_names, " ")
        end
    end,
})
```

## Use A Check Mark `✓` On Message Complete

Use a green check mark `✓` on lsp message complete, follow the [fidget.nvim](https://github.com/j-hui/fidget.nvim) style.

?> Credit: [@ryanmsnyder](https://github.com/ryanmsnyder), see: <https://github.com/linrongbin16/lsp-progress.nvim/discussions/59>.

<video width="80%" controls>
  <source src="https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/486e6ddf-6349-40c6-8643-04afb0fe61a3" type="video/mp4">
</video>

Configurations:

```lua
-- Create a highlighting group with green color
vim.cmd([[ hi LspProgressMessageCompleted ctermfg=Green guifg=Green ]])

require("lsp-progress").setup({
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
        -- return table.concat(builder, " ")
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
            -- replace the check mark once done
            spinner = "%#LspProgressMessageCompleted#✓%*"
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

```lua
local function LspIcon()
    local active_clients_count = #vim.lsp.get_active_clients()
    return active_clients_count > 0 and " LSP" or ""
end

local function LspStatus()
    return require("lsp-progress").progress({
        format = function(messages)
            return #messages > 0 and table.concat(messages, " ") or ""
        end,
    })
end

require('lualine').setup({
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      "branch",
      "diff",
    },
    lualine_c = {
      "filename",
      "diagnostics",
      LspIcon,
      LspStatus,
    },
    ...
  }
})

vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
vim.api.nvim_create_autocmd("User LspProgressStatusUpdated", {
    group = "lualine_augroup",
    callback = require("lualine").refresh,
})
```

## Put Progress On The Right Side

Put lsp progress messages on the right side of lualine.

?> Credit: [@daephx](https://github.com/daephx), see: <https://github.com/linrongbin16/lsp-progress.nvim/issues/25#issuecomment-1742078478>.

<video width="80%" controls>
  <source src="https://github.com/linrongbin16/lsp-progress.nvim/assets/6496887/cc6fbc56-cb17-496a-9bf0-dc1c87d10413" type="video/mp4">
</video>

Minimal `init.lua` (Windows 10 x86_64, Neovim v0.9.2):

```lua
local root = vim.fn.stdpath("data")

-- bootstrap lazy
local lazypath = root .. "/lazy/plugins/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
    })
end
vim.opt.runtimepath:prepend(lazypath)

-- install plugins
local plugins = {
    { -- Initialize language server configuration
        "neovim/nvim-lspconfig",
        cmd = { "LspInfo", "LspInstall", "LspUninstall" },
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            { "williamboman/mason.nvim", config = true },
            { "folke/neodev.nvim", config = true },
        },
        config = function()
            require("lspconfig")["lua_ls"].setup({
                settings = {
                    Lua = {
                        diagnostics = {
                            enable = true,
                            globals = { "vim" },
                        },
                        workspace = {
                            checkThirdParty = false,
                        },
                    },
                },
            })
        end,
    },
    {
        "jose-elias-alvarez/null-ls.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local null_ls = require("null-ls")
            null_ls.setup({
                sources = { null_ls.builtins.formatting.stylua },
            })
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        event = "UIEnter",
        dependencies = {
            -- Lua fork of vim-web-devicons for neovim
            { "nvim-tree/nvim-web-devicons" },
            -- A performant lsp progress status for Neovim.
            {
                "linrongbin16/lsp-progress.nvim",
                config = true,
                -- dev = true,
                -- dir = "~/github/linrongbin16/lsp-progress.nvim",
            },
        },
        config = function(_, opts)
            require("lualine").setup(opts)

            vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
            vim.api.nvim_create_autocmd("User LspProgressStatusUpdated", {
                group = "lualine_augroup",
                callback = require("lualine").refresh,
            })
        end,
        opts = {
            sections = {
                lualine_a = { "mode" },
                lualine_b = {},
                lualine_c = { "filename" },
                lualine_x = {
                    { -- Setup lsp-progress component
                        function()
                            return require("lsp-progress").progress({
                                max_size = 80,
                                format = function(messages)
                                    local active_clients =
                                        vim.lsp.get_active_clients()
                                    if #messages > 0 then
                                        return table.concat(messages, " ")
                                    end
                                    local client_names = {}
                                    for _, client in ipairs(active_clients) do
                                        if client and client.name ~= "" then
                                            table.insert(
                                                client_names,
                                                1,
                                                client.name
                                            )
                                        end
                                    end
                                    return table.concat(client_names, "  ")
                                end,
                            })
                        end,
                        icon = { "", align = "right" },
                    },
                    "diagnostics",
                },
                lualine_y = { "filetype", "encoding", "fileformat" },
                lualine_z = { "location" },
            },
        },
    },
}

-- Attach autocmd to enable auto-formatting on save
vim.api.nvim_create_autocmd({ "LspAttach" }, {
    callback = function(ev)
        -- Apply autocmd if client supports formatting
        vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = ev.buf,
            desc = "Apply Auto-formatting for to document on save",
            group = vim.api.nvim_create_augroup("LspFormat." .. ev.buf, {}),
            callback = function()
                vim.lsp.buf.format({
                    bufnr = ev.buf,
                    filter = function(client)
                        return client.name == "null-ls"
                    end,
                })
            end,
        })
    end,
})

-- Setup lazy.nvim
require("lazy").setup(plugins, {
    root = root .. "/lazy/plugins",
})

```
