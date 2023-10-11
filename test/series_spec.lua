local cwd = vim.fn.getcwd()

describe("series", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

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

    describe("[Series]", function()
        it("create new", function()
            local ss = series.Series:new("title", "message", 10)
            assert_eq(type(ss), "table")
            assert_eq(ss.title, "title")
            assert_eq(ss.message, "message")
            assert_eq(ss.percentage, 10)
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
