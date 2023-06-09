local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local logger = require("lsp-progress.logger")

SeriesRecord = {}









SeriesRecordFormatterType = {}
local SeriesRecordFormatter = nil

function SeriesRecord:tostring()
   return string.format(
   "<SeriesRecord title:%s, message:%s, percentage:%s, done:%s, _formatted:%s>",
   vim.inspect(self.title),
   vim.inspect(self.message),
   vim.inspect(self.percentage),
   vim.inspect(self.done),
   vim.inspect(self._formatted))

end

function SeriesRecord:format()
   if type(SeriesRecordFormatter) == "function" then
      self._formatted = 
      SeriesRecordFormatter(self.title, self.message, self.percentage, self.done)
   end
   logger.debug("|series.SeriesRecord.format| format series: %s", self:tostring())
   return self._formatted
end

function SeriesRecord.new(title, message, percentage)
   local self = setmetatable({}, { __index = SeriesRecord })
   self.title = title
   self.message = message
   self.percentage = percentage
   self.done = false
   self._formatted = nil
   self:format()
   logger.debug("|series.SeriesRecord.new| new series: %s", self:tostring())
   return self
end

function SeriesRecord:formatted_result()
   return self._formatted
end

function SeriesRecord:update(message, percentage)
   self.message = message
   self.percentage = percentage
   self:format()
   logger.debug("|series.SeriesRecord.update| update series: %s", self:tostring())
end

function SeriesRecord:finish(message)
   self.message = message
   self.percentage = 100
   self.done = true
   self:format()
   logger.debug("|series.SeriesRecord.finish| finish series: %s", self:tostring())
end

function SeriesRecord:key()
   return tostring(self.title) .. "-" .. tostring(self.message)
end

local function setup(series_formatter)
   SeriesRecordFormatter = series_formatter
end

local M = {
   setup = setup,
}

return M
