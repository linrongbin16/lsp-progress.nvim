local cwd = vim.fn.getcwd()

describe("lsp-progress", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    local lsp_progress = require("lsp-progress")

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
        lsp_progress.setup()
    end)

    describe("[LspClients]", function()
        it("progress", function()
            assert_eq(type(lsp_progress.progress()), "string")
        end)
        it("add/remove", function()
            lsp_progress._register_client(1, "lua_ls")
            assert_true(lsp_progress._has_client(1))
            local cli = lsp_progress._get_client(1)
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 1)
            assert_eq(cli.client_name, "lua_ls")
            assert_false(lsp_progress._has_client(2))
            lsp_progress._remove_client(1)
            assert_false(lsp_progress._has_client(1))
            assert_false(lsp_progress._has_client(2))
            lsp_progress._register_client(2, "null-ls")
            assert_true(lsp_progress._has_client(2))
            assert_false(lsp_progress._has_client(1))
        end)
    end)
end)
