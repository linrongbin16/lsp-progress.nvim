local EchoHl = {
        ["ERROR"] = "ErrorMsg",
        ["WARN"] = "ErrorMsg",
        ["INFO"] = "None",
        ["DEBUG"] = "Comment",
}
local LogLevel = "INFO"
local UseConsole = true
local UseFile = false
-- For Windows: $env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log
-- For *NIX: ~/.local/share/nvim/lsp-progress.log
local FileName = string.format("%s/lsp-progress.log", vim.fn.stdpath("data"))

local function setup(debug, console_log, file_log, file_log_name)
    if debug then
        LogLevel = "DEBUG"
    end
    UseConsole = console_log
    UseFile = file_log
    FileName = string.format("%s/%s", vim.fn.stdpath("data"), file_log_name)
end

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

local function debug(fmt, ...)
    log("DEBUG", string.format(fmt, ...))
end

local function info(fmt, ...)
    log("INFO", string.format(fmt, ...))
end

local function warn(fmt, ...)
    log("WARN", string.format(fmt, ...))
end

local function error(fmt, ...)
    log("ERROR", string.format(fmt, ...))
end

local M = {
    setup = setup,
    debug = debug,
    info = info,
    warn = warn,
    error = error,
}

return M
