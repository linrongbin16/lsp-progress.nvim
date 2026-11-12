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
                "5:title:message"
            )
            assert_eq(client._get_dedup_key("", ""), "0::")
            assert_eq(client._get_dedup_key(nil, nil), "3:nil:nil")
        end)
        it("never collides on the title/message boundary", function()
            assert_true(
                client._get_dedup_key("a-b", "c")
                    ~= client._get_dedup_key("a", "b-c")
            )
            assert_true(
                client._get_dedup_key("a:", "b")
                    ~= client._get_dedup_key("a", ":b")
            )
            assert_true(
                client._get_dedup_key("1:a", "b")
                    ~= client._get_dedup_key("1", "a:b")
            )
        end)
    end)
    describe("[Client]", function()
        it("create new", function()
            local cli = client.Client:new(1, "luals")
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 1)
            assert_eq(cli.client_name, "luals")
            assert_eq(cli.spin_index, 0)
            -- the cache is built lazily, on the first read.
            assert_eq(cli._format_cache, nil)
            assert_eq(client_format("luals", SPINNER[1], {}), cli:format())
            assert_eq(client_format("luals", SPINNER[1], {}), cli._format_cache)
            assert_eq(
                client_format("luals", SPINNER[1], {}),
                cli:format_result()
            )
            assert_false(cli:has_series("asdf"))
        end)
        it("_format", function()
            local cli = client.Client:new(2, "clangd")
            assert_eq(type(cli), "table")
            assert_eq(cli.client_id, 2)
            assert_eq(cli.client_name, "clangd")
            assert_eq(cli.spin_index, 0)

            assert_eq(client_format("clangd", SPINNER[1], {}), cli:format())
            assert_eq(
                client_format("clangd", SPINNER[1], {}),
                cli._format_cache
            )
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

            -- a series added in this tick is visible without waiting for the
            -- next event-loop iteration.
            assert_eq(
                client_format("clangd", SPINNER[1], {
                    series_formatter("title", "message", 10, false),
                }),
                cli:format_result()
            )
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
        it("dedup series with the same title and message", function()
            local cli = client.Client:new(3, "clangd")
            local ss1 = series.Series:new("title", "message", 50)
            local ss2 = series.Series:new("title", "message", 10)
            cli:add_series("token1", ss1)
            cli:add_series("token2", ss2)

            -- the one that needs more time to complete wins.
            assert_eq(
                client_format("clangd", SPINNER[1], {
                    series_formatter("title", "message", 10, false),
                }),
                cli:format_result()
            )

            cli:remove_series("token2")
            assert_eq(
                client_format("clangd", SPINNER[1], {
                    series_formatter("title", "message", 50, false),
                }),
                cli:format_result()
            )
        end)
        it("does not dedup series that only look alike", function()
            local cli = client.Client:new(5, "clangd")
            cli:add_series("token1", series.Series:new("a-b", "c", 10))
            cli:add_series("token2", series.Series:new("a", "b-c", 20))

            local formatted = cli:format_result()
            assert_true(
                formatted:find(series_formatter("a-b", "c", 10, false), 1, true)
                    ~= nil
            )
            assert_true(
                formatted:find(series_formatter("a", "b-c", 20, false), 1, true)
                    ~= nil
            )
        end)
        it("renders only the latest message after many updates", function()
            local cli = client.Client:new(4, "clangd")
            local ss = series.Series:new("title", "message0", 0)
            cli:add_series("token1", ss)

            -- Every update happens in the same event-loop tick: a read right
            -- after it must already observe the new message.
            for i = 1, 5 do
                ss:update("message" .. i, i * 10)
                cli:add_series("token1", ss)
                assert_eq(
                    client_format("clangd", SPINNER[1], {
                        series_formatter(
                            "title",
                            "message" .. i,
                            i * 10,
                            false
                        ),
                    }),
                    cli:format_result()
                )
            end

            -- the dedup map is built on the fly, so the client only tracks the
            -- live series and nothing grows with the update count.
            assert_eq(vim.tbl_count(cli.serieses), 1)
            assert_true(cli._deduped_tokens == nil)

            cli:remove_series("token1")
            assert_eq(
                client_format("clangd", SPINNER[1], {}),
                cli:format_result()
            )
        end)
    end)
end)
