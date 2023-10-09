local logger = require("lsp-progress.logger")

--- @alias SeriesFormatResult string|any|nil
--- @alias SeriesFormat fun(title:string?,message:string?,percentage:integer?,done:boolean):SeriesFormatResult
--- @type SeriesFormat?
local SeriesFormat = nil

--- @class Series
--- @field title string?
--- @field message string?
--- @field percentage integer?
--- @field done boolean
--- @field private _format_cache SeriesFormatResult
local Series = {
    title = nil,
    message = nil,
    percentage = nil,
    done = false,
    _format_cache = nil,
}

--- @param title string?
--- @param message string?
--- @param percentage integer?
--- @return Series
function Series:new(title, message, percentage)
    local o = {
        title = title,
        message = message,
        percentage = percentage,
        done = false,
        _format_cache = nil,
    }

    setmetatable(o, self)
    self.__index = self

    o:_format()
    logger.debug("|series - Series:new| new series: %s", vim.inspect(o))

    return o
end

--- @return string
function Series:tostring()
    return string.format(
        "<Series title:%s, message:%s, percentage:%s, done:%s, _format_cache:%s>",
        vim.inspect(self.title),
        vim.inspect(self.message),
        vim.inspect(self.percentage),
        vim.inspect(self.done),
        vim.inspect(self._format_cache)
    )
end

--- @param old_message string?
--- @param new_message string?
--- @return string?
local function _update_message(old_message, new_message)
    -- if the 'new' message is nil, it usually means the lifecycle of this message series is going to end.
    -- thus we can decay the latest visible 'old' message for user.
    if type(new_message) == "string" and string.len(new_message) > 0 then
        return new_message
    else
        return old_message
    end
end

--- @param message string
--- @param percentage integer
function Series:update(message, percentage)
    self.message = _update_message(self.message, message)
    self.percentage = percentage
    self:_format()
    logger.debug("|series.update| Update series: %s", self:tostring())
end

--- @param message string
function Series:finish(message)
    self.message = _update_message(self.message, message)
    self.percentage = 100
    self.done = true
    self:_format()
    logger.debug("|series.finish| Finish series: %s", self:tostring())
end

--- @package
--- @return SeriesFormatResult
function Series:_format()
    assert(SeriesFormat ~= nil, "SeriesFormat cannot be null")

    local ok, result_or_err = pcall(
        SeriesFormat,
        self.title,
        self.message,
        self.percentage,
        self.done
    )

    logger.ensure(
        ok,
        "failed to invoke 'series_format' function! error: %s, params: %s, %s, %s, %s",
        vim.inspect(result_or_err),
        vim.inspect(self.title),
        vim.inspect(self.message),
        vim.inspect(self.percentage),
        vim.inspect(self.done)
    )

    self._format_cache = result_or_err
    logger.debug(
        "|series - Series:_format| format series: %s",
        vim.inspect(self)
    )

    return self._format_cache
end

--- @return SeriesFormatResult
function Series:format_result()
    return self._format_cache
end

--- @param series_format SeriesFormat
local function setup(series_format)
    SeriesFormat = series_format
end

local M = {
    setup = setup,
    Series = Series,
}

return M
