--- @type table<string, function>
local logger = require("lsp-progress.logger")

local WINDOW_SHOW_MESSAGE_TOKEN = "window/showMessage:token"

--- @alias SeriesFormatResult string|table|nil

--- @class SeriesObject
--- @field protocol Protocol|nil
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
    protocol = nil,

    -- formatted cache
    _format_cache = nil,
}

--- @alias SeriesFormatterType fun(title:string|nil,message:string|nil,percentage:integer|nil,done:boolean,protocol:Protocol|nil):string|table|nil

--- @type SeriesFormatterType|nil
local SeriesFormatter = nil

--- @return string
function SeriesObject:tostring()
    return string.format(
        "<Series protocol:%s, title:%s, message:%s, percentage:%s, done:%s, _format_cache:%s>",
        vim.inspect(self.protocol),
        vim.inspect(self.title),
        vim.inspect(self.message),
        vim.inspect(self.percentage),
        vim.inspect(self.done),
        vim.inspect(self._format_cache)
    )
end

--- @param message string
--- @param percentage integer
--- @return nil
function SeriesObject:update(message, percentage)
    self.message = message
    self.percentage = percentage
    self:_format()
    logger.debug("|series.update| Update series: %s", self:tostring())
end

--- @param message string
--- @return nil
function SeriesObject:finish(message)
    self.message = message
    self.percentage = 100
    self.done = true
    self:_format()
    logger.debug("|series.finish| Finish series: %s", self:tostring())
end

--- @package
--- @return SeriesFormatResult
function SeriesObject:_format()
    assert(SeriesFormatter ~= nil, "SeriesFormatter cannot be null")
    self._format_cache = SeriesFormatter(
        self.title,
        self.message,
        self.percentage,
        self.done,
        self.protocol,
    )
    logger.debug("|series._format| Format series: %s", self:tostring())
    return self._format_cache
end

--- @return SeriesFormatResult
function SeriesObject:format_result()
    return self._format_cache
end

--- @param title string|nil
--- @param message string
--- @param percentage integer|nil
--- @param protocol Protocol
--- @return SeriesObject
local function new_series(title, message, percentage, protocol)
    --- @type SeriesObject
    local series = vim.tbl_extend("force", vim.deepcopy(SeriesObject), {
        title = tostring(title), -- here translate nil to 'nil'
        message = message,
        percentage = percentage,
        done = false,
        protocol = protocol,
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
    --- @string WINDOW_SHOW_MESSAGE_TOKEN
    WINDOW_SHOW_MESSAGE_TOKEN = WINDOW_SHOW_MESSAGE_TOKEN,
}

return M