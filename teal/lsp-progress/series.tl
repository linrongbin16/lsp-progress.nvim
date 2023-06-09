local logger = require("lsp-progress.logger")

local record SeriesRecord
    title: string|nil
    message: string|nil
    percentage: number|nil
    done: boolean

    -- cached format result
    _formatted: string|any|nil
end
local type SeriesRecordFormatterType = function(string|nil,string|nil,number|nil,boolean|nil):string|any|nil

local SeriesRecordFormatter:SeriesRecordFormatterType|nil = nil

function SeriesRecord:tostring():string
    return string.format(
        "<SeriesRecord title:%s, message:%s, percentage:%s, done:%s, _formatted:%s>",
        vim.inspect(self.title),
        vim.inspect(self.message),
        vim.inspect(self.percentage),
        vim.inspect(self.done),
        vim.inspect(self._formatted)
    )
end

function SeriesRecord:format():string|any|nil
    if SeriesRecordFormatter is SeriesRecordFormatterType then
        self._formatted =
            SeriesRecordFormatter(self.title, self.message, self.percentage, self.done)
    end
    logger.debug("|series.SeriesRecord.format| format series: %s", self:tostring())
    return self._formatted
end

function SeriesRecord:formatted_result():string|any|nil
    return self._formatted
end

function SeriesRecord:update(message:string|nil, percentage:number|nil):nil
    self.message = message
    self.percentage = percentage
    self:format()
    logger.debug("|series.SeriesRecord.update| update series: %s", self:tostring())
end

function SeriesRecord:finish(message:string|nil):nil
    self.message = message
    self.percentage = 100
    self.done = true
    self:format()
    logger.debug("|series.SeriesRecord.finish| finish series: %s", self:tostring())
end

local function setup(series_formatter:SeriesRecordFormatterType):nil
    SeriesRecordFormatter = series_formatter
end

local function new_series(title:string|nil, message:string|nil, percentage:number|nil):SeriesRecord
    local self:SeriesRecord = vim.tbl_extend("force", vim.deepcopy(SeriesRecord) as table, {}) as SeriesRecord
    self.title = title
    self.message = message
    self.percentage = percentage
    self.done = false
    self._formatted = nil
    self:format()
    logger.debug("|series.SeriesRecord.new| new series: %s", self:tostring())
    return self
end

local M:table = {
    setup = setup,
    new_series = new_series
}

return M
