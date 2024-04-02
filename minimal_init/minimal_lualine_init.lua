-- bootstrap lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
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
    {
        "nvim-lualine/lualine.nvim",
        event = "VimEnter",
        dependencies = {
            "nvim-tree/nvim-web-devicons",
            {
                "linrongbin16/lsp-progress.nvim",
                opts = {},
            },
        },
        config = function(_, opts)
            require("lualine").setup(opts)

            vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
            vim.api.nvim_create_autocmd("User", {
                group = "lualine_augroup",
                pattern = "LspProgressStatusUpdated",
                callback = require("lualine").refresh,
            })
        end,
        opts = {
            options = {
                component_separators = { left = "|", right = "|" },
                globalstatus = true,
            },
            sections = {
                lualine_a = {
                    {
                        "mode",
                        fmt = function(str)
                            return str:sub(1, 1)
                        end,
                    },
                },
                lualine_b = {
                    { "branch", icons_enabled = false },
                },
                lualine_c = {
                    require("lsp-progress").progress,
                },
            },
            tabline = {
                lualine_a = {
                    "buffers",
                },
            },
        },
    },
}

-- Setup lazy.nvim
require("lazy").setup(plugins)
