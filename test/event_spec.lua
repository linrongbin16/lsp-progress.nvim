local cwd = vim.fn.getcwd()

describe("event", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
        vim.o.swapfile = false
        vim.cmd([[edit README.md]])
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
    describe("[emit/reset]", function()
        event.setup("TestEvent", 1000, 1000, {})
        it("emit", function()
            assert_true(event.emit())
        end)
        it("reset", function()
            assert_false(event.reset())
        end)
    end)
    describe("[GlobalDisabledEventOptsManager]", function()
        it("disable all events", function()
            event.setup("TestEvent", 1000, 1000, {
                { mode = "i", filetype = "TelescopePrompt" },
                { mode = "i", filetype = "lua" },
                { mode = "*", filetype = "*" },
            })
            assert_false(event.emit())
        end)
        it("allows event", function()
            event.setup("TestEvent", 1000, 1000, {
                { mode = "i", filetype = "TelescopePrompt" },
                { mode = "i", filetype = "lua" },
            })
            assert_true(event.emit())
        end)
    end)
end)
