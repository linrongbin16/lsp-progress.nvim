local cwd = vim.fn.getcwd()

describe("event", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local event = require("lsp-progress.event")
    describe("[DisableEventOpt]", function()
        it("not match current buffer", function()
            local opt =
                event.DisableEventOpt:new({ mode = "i", filetype = "lua" })
            assert_false(opt:match())
        end)
        it("match everything", function()
            local opt =
                event.DisableEventOpt:new({ mode = "*", filetype = "*" })
            assert_true(opt:match())
        end)
    end)
    describe("[DisableEventOptsManager]", function()
        it("not match current buffer", function()
            local opts = {
                event.DisableEventOpt:new({
                    mode = "i",
                    filetype = "TelescopePrompt",
                }),
                event.DisableEventOpt:new({ mode = "i", filetype = "lua" }),
            }
            local manager = event.DisableEventOptsManager:new(opts)
            assert_false(manager:match())
        end)
        it("match everything", function()
            local opts = {
                event.DisableEventOpt:new({
                    mode = "i",
                    filetype = "TelescopePrompt",
                }),
                event.DisableEventOpt:new({ mode = "i", filetype = "lua" }),
                event.DisableEventOpt:new({ mode = "*", filetype = "*" }),
            }
            local manager = event.DisableEventOptsManager:new(opts)
            assert_true(manager:match())
        end)
    end)
end)
