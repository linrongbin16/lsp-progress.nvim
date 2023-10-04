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