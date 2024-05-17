local cwd = vim.fn.getcwd()

describe("api", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local api = require("lsp-progress.api")

    describe("[lsp_clients]", function()
        it("counts", function()
            assert_eq(type(api.lsp_clients()), "table")
            assert_eq(type(#api.lsp_clients()), "number")
        end)
    end)
end)
