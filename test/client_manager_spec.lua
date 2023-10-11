local cwd = vim.fn.getcwd()

describe("client_manager", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local client = require("lsp-progress.client")

    local function client_format(client_name, spinner, series_messages)
        return string.format(
            "%s, %s, %s",
            vim.inspect(client_name),
            vim.inspect(spinner),
            vim.inspect(series_messages)
        )
    end

    local SPINNER = { "a", "b", "c" }

    client.setup(client_format, SPINNER)
    local client_manager = require("lsp-progress.client_manager")

    describe("[ClientManager]", function()
        it("create", function()
            local cm = client_manager.ClientManager:new()
            assert_true(cm:empty())
            assert_false(cm:has(1))
        end)
        it("register", function()
            local cm = client_manager.ClientManager:new()
            assert_true(cm:empty())
            assert_false(cm:has(1))
            cm:register(1, "luals")
            assert_false(cm:empty())
            assert_true(cm:has(1))
            assert_false(cm:has(2))
            local cli1 = cm:get(1)
            assert_eq(type(cli1), "table")
            assert_eq(cli1.client_id, 1)
            assert_eq(cli1.client_name, "luals")
        end)
        it("remove", function()
            local cm = client_manager.ClientManager:new()
            assert_true(cm:empty())
            assert_false(cm:has(1))
            cm:register(1, "luals")
            assert_false(cm:empty())
            assert_true(cm:has(1))
            assert_false(cm:has(2))
            cm:remove(1)
            assert_false(cm:has(1))
        end)
    end)
end)
