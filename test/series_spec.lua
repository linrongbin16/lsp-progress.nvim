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
        it("create new", function()
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
    end)
end)
