local logger = require("lsp-progress.logger")

--- @alias SeriesFormatResult string|table|nil

--- @class SeriesObject
--- @field title string|nil
--- @field message string|nil
--- @field percentage integer|nil
--- @field done boolean
--- @field private _format_cache SeriesFormatResult
---     formatted cache
local SeriesObject = {
    title = nil,
    message = nil,
    percentage = nil,
    done = false,

    -- formatted cache
    _format_cache = nil,
}

--- @alias SeriesFormatterType fun(title:string|nil,message:string|nil,percentage:integer|nil,done:boolean):string|table|nil

--- @type SeriesFormatterType|nil
local SeriesFormatter = nil

--- @return string
function SeriesObject:tostring()
    return string.format(
        "<Series title:%s, message:%s, percentage:%s, done:%s, _format_cache:%s>",
        vim.inspect(self.title),
        vim.inspect(self.message),
        vim.inspect(self.percentage),
        vim.inspect(self.done),
        vim.inspect(self._format_cache)
    )
end

--- @param old_message string|nil
--- @param new_message string|nil
--- @return string|nil
local function updated_message(old_message, new_message)
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
--- @return nil
function SeriesObject:update(message, percentage)
    self.message = updated_message(self.message, message)
    self.percentage = percentage
    self:_format()
    logger.debug("|series.update| Update series: %s", self:tostring())
end

--- @param message string
--- @return nil
function SeriesObject:finish(message)
    self.message = updated_message(self.message, message)
    self.percentage = 100
    self.done = true
    self:_format()
    logger.debug("|series.finish| Finish series: %s", self:tostring())
end

--- @package
--- @return SeriesFormatResult
function SeriesObject:_format()
    assert(SeriesFormatter ~= nil, "SeriesFormatter cannot be null")
    local ok, result = pcall(
        SeriesFormatter,
        self.title,
        self.message,
        self.percentage,
        self.done
    )

    if not ok then
        logger.throw(
            "failed to invoke 'series_format' function! error: %s, params: %s, %s, %s, %s",
            vim.inspect(result),
            vim.inspect(self.title),
            vim.inspect(self.message),
            vim.inspect(self.percentage),
            vim.inspect(self.done)
        )
    end

    self._format_cache = result
    logger.debug("|series._format| Format series: %s", self:tostring())
    return self._format_cache
end

--- @return SeriesFormatResult
function SeriesObject:format_result()
    return self._format_cache
end

--- @param title string
--- @param message string
--- @param percentage integer
--- @return SeriesObject
local function new_series(title, message, percentage)
    --- @type SeriesObject
    local series = vim.tbl_extend("force", vim.deepcopy(SeriesObject), {
        title = title,
        message = message,
        percentage = percentage,
        done = false,
    })
    series:_format()
    logger.debug("|series.new_series| New series: %s", series:tostring())
    return series
end

--- @param formatter SeriesFormatterType
--- @return nil
local function setup(formatter)
    SeriesFormatter = formatter
end

--- @type table<string, function>
local M = {
    --- @overload fun(formatter:SeriesFormatterType):nil
    setup = setup,
    --- @overload fun(title:string, message:string, percentage:integer):SeriesObject
    new_series = new_series,
}

return M
