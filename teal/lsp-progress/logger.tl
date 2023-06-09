local enum LogLevelEnum
    "ERROR"
    "WARN"
    "INFO"
    "DEBUG"
end
local enum EchoHlEnum
    "ErrorMsg"
    "WarningMsg"
    "None"
    "Comment"
end
local EchoHl:{LogLevelEnum:EchoHlEnum} = {
    ["ERROR"] = "ErrorMsg",
    ["WARN"] = "WarningMsg",
    ["INFO"] = "None",
    ["DEBUG"] = "Comment",
}
local PathSeparator = vim.fn.has('win32') > 0 and "\\" or "/"
local LogLevel:LogLevelEnum = "INFO"
local ConsoleLog = true
local FileLog = false
local FileLogName = "lsp-progress.log"
local FileLogPath:string|nil = nil

local function setup(enable_debug:boolean, console_log:boolean, file_log:boolean, file_log_name:string|nil): nil
    if enable_debug then
        LogLevel = "DEBUG"
    end
    ConsoleLog = console_log
    FileLog = file_log
    if file_log_name and string.len(file_log_name) > 0 then
        FileLogName = file_log_name
    end
    if FileLog then
        FileLogPath = vim.fn.stdpath("data") .. PathSeparator .. FileLogName
    end
end

local function log(level:LogLevelEnum, message:string):nil
    if vim.log.levels[level] < vim.log.levels[LogLevel] then
        return
    end

    local split_messages = vim.split(message, "\n")
    if ConsoleLog then
        vim.cmd("echohl " .. EchoHl[level])
        for _, line in ipairs(split_messages) do
            vim.cmd(
                string.format(
                    'echom "%s"',
                    vim.fn.escape(string.format("lsp-progress: %s", line), '"')
                )
            )
        end
        vim.cmd("echohl None")
    end
    if FileLog then
        local fp = io.open(FileLogPath, "a")
        if fp then
            for _, line in ipairs(split_messages) do
                fp:write(
                    string.format(
                        "lsp-progress: %s [%s]: %s\n",
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

local function debug(fmt:string, ...:any):nil
    log("DEBUG", string.format(fmt, ...))
end

local function info(fmt:string, ...:any):nil
    log("INFO", string.format(fmt, ...))
end

local function warn(fmt:string, ...:any):nil
    log("WARN", string.format(fmt, ...))
end

local function err(fmt:string, ...:any):nil
    log("ERROR", string.format(fmt, ...))
end

local M = {
    setup = setup,
    debug = debug,
    info = info,
    warn = warn,
    err = err,
}

return M
