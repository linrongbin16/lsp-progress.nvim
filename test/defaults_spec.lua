local cwd = vim.fn.getcwd()

describe("defaults", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local function equals_to(a, b)
        if type(a) ~= type(b) then
            print(
                string.format(
                    "type(a) (%s) ~= type(b) (%s)\n",
                    vim.inspect(type(a)),
                    vim.inspect(type(b))
                )
            )
            return false
        end
        if type(a) == "table" then
            for ka, va in pairs(a) do
                local vb = b[ka]
                if not equals_to(va, vb) then
                    print(
                        string.format(
                            "ka (%s), va (%s) ~= vb (%s)\n",
                            vim.inspect(ka),
                            vim.inspect(va),
                            vim.inspect(vb)
                        )
                    )
                    return false
                end
            end
            return true
        end
        print(
            string.format(
                "a (%s) == b (%s): %s\n",
                vim.inspect(a),
                vim.inspect(b),
                vim.inspect(a == b)
            )
        )
        return a == b
    end

    local defaults = require("lsp-progress.defaults")
    describe("[get_defaults]", function()
        it("is defaults", function()
            local df = defaults._get_defaults()
            assert_eq(type(df), "table")
            assert_eq(type(df.spinner), "table")
            assert_eq(df.spin_update_time, 200)
            assert_eq(df.decay, 700)
            assert_eq(df.event, "LspProgressStatusUpdated")
            assert_eq(df.event_update_time_limit, 50)
            assert_eq(df.max_size, -1)
            assert_eq(df.regular_internal_update_time, 500)
            assert_eq(type(df.series_format), "function")
            assert_eq(
                type(df.series_format("title", "message", 10, true)),
                "string"
            )
            assert_true(
                string.len(df.series_format("title", "message", 10, true)) > 0
            )
            assert_eq(type(df.client_format), "function")
            assert_eq(
                type(df.client_format("luals", "x", { "a", "b", "c" })),
                "string"
            )
            assert_true(
                string.len(df.client_format("luals", "x", { "a", "b", "c" }))
                    > 0
            )
            assert_eq(type(df.format), "function")
            assert_eq(type(df.format({ "a", "b", "c" })), "string")
            assert_true(string.len(df.format({ "a", "b", "c" })) > 0)
        end)
        it("setup", function()
            local cfg = defaults.setup()
            local dfs = defaults._get_defaults()
            assert_eq(type(cfg), "table")
            assert_eq(type(dfs), "table")
            assert_true(equals_to(cfg, dfs))
        end)
    end)
end)
