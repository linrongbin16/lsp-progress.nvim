local logger = require("lsp-progress.logger")

--- @alias lsp_progress.SeriesFormatResult string|any|nil
--- @alias lsp_progress.SeriesFormat fun(title:string?,message:string?,percentage:integer?,done:boolean):lsp_progress.SeriesFormatResult
--- @type lsp_progress.SeriesFormat?
local SeriesFormat = nil

--- @class lsp_progress.Series
--- @field title string?
--- @field message string?
--- @field percentage integer?
--- @field done boolean
--- @field private _format_cache lsp_progress.SeriesFormatResult
local Series = {}

--- @param title string?
--- @param message string?
--- @param percentage integer?
--- @return lsp_progress.Series
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
    -- logger.debug("|series - Series:new| new: %s", vim.inspect(o))

    return o
end

--- @package
--- @return lsp_progress.SeriesFormatResult
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
        "failed to invoke 'series_format' function with params: %s! error: %s",
        vim.inspect(self),
        vim.inspect(result_or_err)
    )

    self._format_cache = result_or_err
    -- logger.debug("|series - Series:_format| format: %s", vim.inspect(self))

    return self._format_cache
end

--- @param old_message string?
--- @param new_message string?
--- @return string?
local function _choose_updated_message(old_message, new_message)
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
    self.message = _choose_updated_message(self.message, message)
    self.percentage = percentage
    self:_format()
    -- logger.debug("|series - Series:update| update: %s", vim.inspect(self))
end

--- @param message string
function Series:finish(message)
    self.message = _choose_updated_message(self.message, message)
    self.percentage = 100
    self.done = true
    self:_format()
    -- logger.debug("|series - Series:finish| finish: %s", vim.inspect(self))
end

--- @return lsp_progress.SeriesFormatResult
function Series:format_result()
    return self._format_cache
end

--- @param series_format lsp_progress.SeriesFormat
local function setup(series_format)
    SeriesFormat = series_format
end

local M = {
    setup = setup,
    Series = Series,
    _choose_updated_message = _choose_updated_message,
}

return M
