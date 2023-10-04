local cwd = vim.fn.getcwd()

describe("logger", function()
    local assert_eq = assert.is_equal
    local assert_true = assert.is_true
    local assert_false = assert.is_false

    before_each(function()
        vim.api.nvim_command("cd " .. cwd)
    end)

    local logger = require("lsp-progress.logger")
    logger.setup("DEBUG", true, true, "lsp-progress-test.log")
    describe("[log]", function()
        it("debug", function()
            logger.debug("debug without parameters")
            logger.debug("debug with 1 parameters: %s", "a")
            logger.debug("debug with 2 parameters: %s, %d", "a", 1)
            logger.debug("debug with 3 parameters: %s, %d, %f", "a", 1, 3.12)
            assert_true(true)
        end)
        it("info", function()
            logger.info("info without parameters")
            logger.info("info with 1 parameters: %s", "a")
            logger.info("info with 2 parameters: %s, %d", "a", 1)
            logger.info("info with 3 parameters: %s, %d, %f", "a", 1, 3.12)
            assert_true(true)
        end)
        it("warn", function()
            logger.warn("warn without parameters")
            logger.warn("warn with 1 parameters: %s", "a")
            logger.warn("warn with 2 parameters: %s, %d", "a", 1)
            logger.warn("warn with 3 parameters: %s, %d, %f", "a", 1, 3.12)
            assert_true(true)
        end)
        it("err", function()
            logger.err("err without parameters")
            logger.err("err with 1 parameters: %s", "a")
            logger.err("err with 2 parameters: %s, %d", "a", 1)
            logger.err("err with 3 parameters: %s, %d, %f", "a", 1, 3.12)
            assert_true(true)
        end)
        it("throw", function()
            local ok1, msg1 = pcall(logger.throw, "throw without parameters")
            local ok2, msg2 =
                pcall(logger.throw, "throw with 1 parameters: %s", "a")
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
                logger.ensure,
                true,
                "ensure successfully without parameters"
            )
            local ok2, msg2 = pcall(
                logger.ensure,
                false,
                "ensure failure with 1 parameters: %s",
                "a"
            )
            assert_true(ok1)
            assert_true(msg1 == nil)
            assert_false(ok2)
            assert_eq(type(msg2), "string")
            assert_true(string.len(msg2) > 0)
        end)
    end)
end)
