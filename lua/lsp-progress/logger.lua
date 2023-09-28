local PATH_SEPARATOR = (vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0)
        and "\\"
    or "/"

local LogLevels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    OFF = 5,
}

local LogHighlights = {
    [1] = "Comment",
    [2] = "None",
    [3] = "WarningMsg",
    [4] = "ErrorMsg",
}

--- @type Configs
local Configs = {
    level = LogLevels.INFO,
    use_console = true,
    use_file = false,
    file_name = "lsp-progress.log",
}

--- @param debug boolean
--- @param console_log boolean
--- @param file_log boolean
--- @param file_log_name string
--- @return nil
local function setup(debug, console_log, file_log, file_log_name)
    Configs.level = debug and LogLevels.DEBUG or LogLevels.INFO
    Configs.use_console = console_log
    Configs.use_file = file_log
    -- For Windows: $env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log
    -- For *NIX: ~/.local/share/nvim/lsp-progress.log
    Configs.file_name = string.format(
        "%s%s%s",
        vim.fn.stdpath("data"),
        PATH_SEPARATOR,
        file_log_name
    )
end

--- @param level integer
--- @param msg string
local function log(level, msg)
    if level < Configs.level then
        return
    end

    local msg_lines = vim.split(msg, "\n", { plain = true })
    if Configs.use_console and level >= LogLevels.INFO then
        local msg_chunks = {}
        for _, line in ipairs(msg_lines) do
            table.insert(msg_chunks, {
                string.format("[lsp-progress] %s\n", line),
                LogHighlights[level],
            })
        end
        vim.api.nvim_echo(msg_chunks, false, {})
    end
    if Configs.use_file then
        local fp = io.open(Configs.file_name, "a")
        if fp then
            for _, line in ipairs(msg_lines) do
                fp:write(
                    string.format(
                        "%s [%s]: %s\n",
                        os.date("%Y-%m-%d %H:%M:%S"),
                        level,
                        line
                    )
                )
            end
            fp:close()
        end
    end
end

--- @param fmt string
--- @param ... any
local function debug(fmt, ...)
    log(LogLevels.DEBUG, string.format(fmt, ...))
end

--- @param fmt string
--- @param ... any
local function info(fmt, ...)
    log(LogLevels.INFO, string.format(fmt, ...))
end

--- @param fmt string
--- @param ... any
local function warn(fmt, ...)
    log(LogLevels.WARN, string.format(fmt, ...))
end

--- @param fmt string
--- @param ... any
local function error(fmt, ...)
    log(LogLevels.ERROR, string.format(fmt, ...))
end

local M = {
    setup = setup,
    debug = debug,
    info = info,
    warn = warn,
    error = error,
}

return M
