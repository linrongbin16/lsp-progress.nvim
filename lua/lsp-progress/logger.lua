--- @type string
local PATH_SEPARATOR = (vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0)
        and "\\"
    or "/"

--- @type table<string, integer>
local LogLevels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    OFF = 5,
}

--- @type table<string, string>
local EchoHl = {
    ERROR = "ErrorMsg",
    WARN = "WarningMsg",
    INFO = "None",
    DEBUG = "Comment",
}

--- @type table<string, string|boolean|nil>
local Configs = {
    --- @type string
    level = "INFO",
    --- @type boolean?
    use_console = nil,
    --- @type boolean?
    use_file = nil,
    --- @type string?
    file_name = nil,
}

--- @param debug boolean
--- @param console_log boolean
--- @param file_log boolean
--- @param file_log_name string
--- @return nil
local function setup(debug, console_log, file_log, file_log_name)
    if debug then
        Configs.level = "DEBUG"
    end
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

--- @param level "ERROR"|"WARN"|"INFO"|"DEBUG"
--- @param msg string
--- @return nil
local function log(level, msg)
    if LogLevels[level] < LogLevels[Configs.level] then
        return
    end

    local msg_lines = vim.fn.split(msg, "\n")
    if Configs.use_console then
        local msg_chunks = {}
        for _, line in ipairs(msg_lines) do
            table.insert(msg_chunks, {
                string.format("[lsp-progress] %s\n", line),
                EchoHl[level],
            })
        end
        vim.api.nvim_echo(msg_chunks, true, {})
    end
    if Configs.use_file then
        local fp = io.open(Configs.file_name --[[@as string]], "a")
        if fp then
            for _, line in ipairs(msg_lines) do
                fp:write(
                    string.format(
                        "[lsp-progress] %s [%s]: %s\n",
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
--- @return nil
local function debug(fmt, ...)
    log("DEBUG", string.format(fmt, ...))
end

--- @param fmt string
--- @param ... any
--- @return nil
local function info(fmt, ...)
    log("INFO", string.format(fmt, ...))
end

--- @param fmt string
--- @param ... any
--- @return nil
local function warn(fmt, ...)
    log("WARN", string.format(fmt, ...))
end

--- @param fmt string
--- @param ... any
--- @return nil
local function error(fmt, ...)
    log("ERROR", string.format(fmt, ...))
end

--- @type table<string, function>
local M = {
    setup = setup,
    debug = debug,
    info = info,
    warn = warn,
    error = error,
}

return M