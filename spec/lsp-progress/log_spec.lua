local cwd = vim.fn.getcwd()

describe("log", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local log = require("lsp-progress.log")
    log.setup({
        level = vim.log.levels.DEBUG,
        use_console = true,
        use_file = true,
        file_name = "lsp-progress-test.log",
    })

    describe("[log]", function()
        it("debug", function()
            log.debug("debug without parameters")
            log.debug(string.format("debug with 1 parameters: %s", "a"))
            log.debug(string.format("debug with 2 parameters: %s, %d", "a", 1))
            log.debug(
                string.format(
                    "debug with 3 parameters: %s, %d, %f",
                    "a",
                    1,
                    3.12
                )
            )
            assert_true(true)
        end)
        it("info", function()
            log.info("info without parameters")
            log.info(string.format("info with 1 parameters: %s", "a"))
            log.info(string.format("info with 2 parameters: %s, %d", "a", 1))
            log.info(
                string.format(
                    "info with 3 parameters: %s, %d, %f",
                    "a",
                    1,
                    3.12
                )
            )
            assert_true(true)
        end)
        it("warn", function()
            log.warn("warn without parameters")
            log.warn(string.format("warn with 1 parameters: %s", "a"))
            log.warn(string.format("warn with 2 parameters: %s, %d", "a", 1))
            log.warn(
                string.format(
                    "warn with 3 parameters: %s, %d, %f",
                    "a",
                    1,
                    3.12
                )
            )
            assert_true(true)
        end)
        it("err", function()
            log.err("err without parameters")
            log.err(string.format("err with 1 parameters: %s", "a"))
            log.err(string.format("err with 2 parameters: %s, %d", "a", 1))
            log.err(
                string.format("err with 3 parameters: %s, %d, %f", "a", 1, 3.12)
            )
            assert_true(true)
        end)
        it("throw", function()
            local ok1, msg1 = pcall(log.throw, "throw without parameters")
            local ok2, msg2 = pcall(
                log.throw,
                string.format("throw with 1 parameters: %s", "a")
            )
            assert_false(ok1)
            assert_eq(type(msg1), "string")
            assert_true(string.len(msg1) > 0)
            assert_false(ok2)
            assert_eq(type(msg2), "string")
            assert_true(string.len(msg2) > 0)
            assert_true(true)
        end)
        it("ensure", function()
            local ok1, msg1 = pcall(
                log.ensure,
                true,
                "ensure successfully without parameters"
            )
            local ok2, msg2 = pcall(
                log.ensure,
                false,
                string.format("ensure failure with 1 parameters: %s", "a")
            )
            assert_true(ok1)
            assert_true(msg1 == nil)
            assert_false(ok2)
            assert_eq(type(msg2), "string")
            assert_true(string.len(msg2) > 0)
        end)
    end)
end)
