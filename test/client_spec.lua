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

    describe("[_get_dedup_key]", function()
        it("normal strings", function()
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
            assert_false(cli:has_series("asdf"))
        end)
        it("_format", function()
            local ss = series.Series:new("title", "message", 10)
            assert_eq(type(ss), "table")
            assert_eq(ss.title, "title")
            assert_eq(ss.message, "message")
            assert_eq(ss.percentage, 10)

            assert_eq(
                series_formatter(ss.title, ss.message, ss.percentage, ss.done),
                ss:_format()
            )
        end)
        it("update", function()
            local ss = series.Series:new("title", "message", 10)
            assert_eq(type(ss), "table")
            assert_eq(ss.title, "title")
            assert_eq(ss.message, "message")
            assert_eq(ss.percentage, 10)
            assert_eq(
                series_formatter(ss.title, ss.message, ss.percentage, ss.done),
                ss:_format()
            )

            ss:update("message2", 20)
            assert_eq(ss.message, "message2")
            assert_eq(ss.percentage, 20)
            assert_eq(
                series_formatter(ss.title, "message2", 20, ss.done),
                ss:_format()
            )

            ss:update("", 30)
            assert_eq(ss.message, "message2")
            assert_eq(ss.percentage, 30)
            assert_eq(
                series_formatter(ss.title, "message2", 30, ss.done),
                ss:_format()
            )

            ss:update(nil, 40)
            assert_eq(ss.message, "message2")
            assert_eq(ss.percentage, 40)
            assert_eq(
                series_formatter(ss.title, "message2", 40, ss.done),
                ss:_format()
            )

            ss:update("message5", 50)
            assert_eq(ss.message, "message5")
            assert_eq(ss.percentage, 50)
            assert_eq(
                series_formatter(ss.title, "message5", 50, ss.done),
                ss:_format()
            )
        end)
        it("finish", function()
            local ss = series.Series:new("title", "message", 10)
            assert_eq(type(ss), "table")
            assert_eq(ss.title, "title")
            assert_eq(ss.message, "message")
            assert_eq(ss.percentage, 10)
            assert_eq(
                series_formatter(ss.title, ss.message, ss.percentage, ss.done),
                ss:_format()
            )

            ss:finish("message2")
            assert_eq(ss.message, "message2")
            assert_eq(ss.percentage, 100)
            assert_eq(ss.done, true)
            assert_eq(
                series_formatter(ss.title, "message2", 100, true),
                ss:_format()
            )

            ss:finish("")
            assert_eq(ss.message, "message2")
            assert_eq(ss.percentage, 100)
            assert_eq(ss.done, true)
            assert_eq(
                series_formatter(ss.title, "message2", 100, ss.done),
                ss:_format()
            )

            ss:finish(nil)
            assert_eq(ss.message, "message2")
            assert_eq(ss.percentage, 100)
            assert_eq(ss.done, true)
            assert_eq(
                series_formatter(ss.title, "message2", 100, ss.done),
                ss:_format()
            )

            ss:finish("message5")
            assert_eq(ss.message, "message5")
            assert_eq(ss.percentage, 100)
            assert_eq(ss.done, true)
            assert_eq(
                series_formatter(ss.title, "message5", 100, ss.done),
                ss:_format()
            )
            assert_eq(
                series_formatter(ss.title, "message5", 100, ss.done),
                ss:format_result()
            )
        end)
    end)
    describe("[_choose_updated_message]", function()
        it("choose non-empty", function()
            assert_eq(series._choose_updated_message(nil, "asdf"), "asdf")
            assert_eq(series._choose_updated_message("", "asdf"), "asdf")
            assert_eq(
                series._choose_updated_message("asdfasdf", "asdf"),
                "asdf"
            )
            assert_eq(
                series._choose_updated_message("asdfasdf", ""),
                "asdfasdf"
            )
            assert_eq(
                series._choose_updated_message("asdfasdf", nil),
                "asdfasdf"
            )
        end)
    end)
end)
