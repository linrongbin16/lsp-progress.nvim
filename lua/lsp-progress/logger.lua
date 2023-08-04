--- @type table<string, string>
local EchoHl = {
    ["ERROR"] = "ErrorMsg",
    ["WARN"] = "WarningMsg",
    ["INFO"] = "None",
    ["DEBUG"] = "Comment",
}

local PathSep = (vim.fn.has("win32") > 0 or vim.fn.has("win64") > 0) and "\\"
    or "/"

--- @type string
local LogLevel = "INFO"
--- @type boolean|nil
local UseConsole = nil
--- @type boolean|nil
local UseFile = nil
--- @type string|nil
local FileName = nil

--- @param debug boolean
--- @param console_log boolean
--- @param file_log boolean
--- @param file_log_name string
--- @return nil
local function setup(debug, console_log, file_log, file_log_name)
    if debug then
        LogLevel = "DEBUG"
    end
    UseConsole = console_log
    UseFile = file_log
    -- For Windows: $env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log
    -- For *NIX: ~/.local/share/nvim/lsp-progress.log
    FileName =
        string.format("%s%s%s", vim.fn.stdpath("data"), PathSep, file_log_name)
end

--- @param level string
--- @param msg string
--- @return nil
local function log(level, msg)
    if vim.log.levels[level] < vim.log.levels[LogLevel] then
        return
    end

    local msg_lines = vim.split(msg, "\n")
    if UseConsole then
        vim.cmd("echohl " .. EchoHl[level])
        for _, line in ipairs(msg_lines) do
            vim.cmd(
                string.format(
                    'echom "%s"',
                    vim.fn.escape(string.format("[lsp-progress] %s", line), '"')
                )
            )
        end
        vim.cmd("echohl None")
    end
    if UseFile then
        assert(
            type(FileName) == "string",
            "error! log filename cannot be empty!"
        )
        assert(string.len(FileName) > 0, "error! log filename cannot be empty!")
        local fp = io.open(FileName, "a")
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