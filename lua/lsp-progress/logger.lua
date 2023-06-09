local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string











local EchoHl = {
   ["ERROR"] = "ErrorMsg",
   ["WARN"] = "WarningMsg",
   ["INFO"] = "None",
   ["DEBUG"] = "Comment",
}
local PathSeparator = vim.fn.has('win32') > 0 and "\\" or "/"
local LogLevel = "INFO"
local ConsoleLog = true
local FileLog = false
local FileLogName = "lsp-progress.log"
local FileLogPath = nil

local function setup(enable_debug, console_log, file_log, file_log_name)
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

local function log(level, message)
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
         vim.fn.escape(string.format("lsp-progress: %s", line), '"')))


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
            line))


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

local function err(fmt, ...)
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
