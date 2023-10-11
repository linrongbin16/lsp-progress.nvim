local cwd = vim.fn.getcwd()

describe("defaults", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local defaults = require("lsp-progress.defaults")
    describe("[get_defaults]", function()
        it("is defaults", function()
            local df = defaults._get_defaults()
            assert_eq(type(df), "table")
            assert_eq(type(df.spinner), "table")
            assert_eq(df.spin_update_time, 200)
            assert_eq(df.decay, 700)
            assert_eq(df.event, "LspProgressStatusUpdated")
        end)
    end)
end)
