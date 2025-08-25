local cwd = vim.fn.getcwd()

describe("client", function()
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

    local series = require("lsp-progress.series")

    local function series_formatter(title, message, percentage, done)
        return string.format(
            "%s, %s, %s, %s",
            vim.inspect(title),
            vim.inspect(message),
            vim.inspect(percentage),
            vim.inspect(done)
        )
    end

    series.setup(series_formatter)

    describe("[_get_dedup_key]", function()
        it("make dedup keys", function()
            assert_eq(
                client._get_dedup_key("title", "message"),
                "title-message"
            )
            assert_eq(client._get_dedup_key("", ""), "-")
            assert_eq(client._get_dedup_key(nil, nil), "nil-nil")
        end)
    end)
    describe("[Client]", function()
        it("create new", function()
            local cli = client.Client:new(1, "luals")
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 1)
            assert_eq(cli.client_name, "luals")
            assert_eq(cli.spin_index, 0)
            assert_eq(client_format("luals", SPINNER[1], {}), cli._format_cache)
            assert_eq(client_format("luals", SPINNER[1], {}), cli:format())
            assert_false(cli:has_series("asdf"))
        end)
        it("_format", function()
            local cli = client.Client:new(2, "clangd")
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 2)
            assert_eq(cli.client_name, "clangd")
            assert_eq(cli.spin_index, 0)

            assert_eq(
                client_format("clangd", SPINNER[1], {}),
                cli._format_cache
            )
            assert_eq(client_format("clangd", SPINNER[1], {}), cli:format())
        end)
        it("add series", function()
            local cli = client.Client:new(2, "clangd")
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 2)
            assert_eq(cli.client_name, "clangd")
            assert_eq(cli.spin_index, 0)

            assert_eq(client_format("clangd", SPINNER[1], {}), cli:format())
            assert_eq(
                client_format("clangd", SPINNER[1], {}),
                cli:format_result()
            )

            local ss = series.Series:new("title", "message", 10)
            cli:add_series("token1", ss)

            assert_true(cli:has_series("token1"))
            assert_false(cli:empty())

            local ss2 = cli:get_series("token1")
            assert_eq(type(ss2), "table")
            assert_eq(ss2.title, ss.title)
            assert_eq(ss2.message, ss.message)
            assert_eq(ss2.percentage, ss.percentage)
            assert_eq(ss2.done, ss.done)

            assert_false(cli:has_series("token2"))
            assert_true(cli:get_series("token2") == nil)
        end)
        it("remove series", function()
            local cli = client.Client:new(2, "clangd")
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 2)
            assert_eq(cli.client_name, "clangd")
            assert_eq(cli.spin_index, 0)

            assert_eq(client_format("clangd", SPINNER[1], {}), cli:format())
            assert_eq(
                client_format("clangd", SPINNER[1], {}),
                cli:format_result()
            )

            local ss = series.Series:new("title", "message", 10)
            cli:add_series("token1", ss)

            assert_true(cli:has_series("token1"))
            assert_false(cli:empty())

            local ss2 = cli:get_series("token1")
            assert_eq(type(ss2), "table")
            assert_eq(ss2.title, ss.title)
            assert_eq(ss2.message, ss.message)
            assert_eq(ss2.percentage, ss.percentage)
            assert_eq(ss2.done, ss.done)

            cli:remove_series("token1")
            assert_false(cli:has_series("token1"))
        end)
    end)
end)
