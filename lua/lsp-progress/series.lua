local logger = require("lsp-progress.logger")

local SeriesObject = {
    title = nil,
    message = nil,
    percentage = nil,
    done = false,

    -- format cache
    _format_cache = nil,
}

local SeriesFormatter = nil

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

function SeriesObject:update(message, percentage)
    self.message = message
    self.percentage = percentage
    self:_format()
    logger.debug("|series.update| Update series: %s", self:tostring())
end

function SeriesObject:finish(message)
    self.message = message
    self.percentage = 100
    self.done = true
    self:_format()
    logger.debug("|series.finish| Finish series: %s", self:tostring())
end

function SeriesObject:key()
    return tostring(self.title) .. "-" .. tostring(self.message)
end

function SeriesObject:priority()
    return self.percentage and self.percentage or -1
end

function SeriesObject:_format()
    self._format_cache =
        SeriesFormatter(self.title, self.message, self.percentage, self.done)
    logger.debug("|series._format| Format series: %s", self:tostring())
    return self._format_cache
end

function SeriesObject:format_result()
    return self._format_cache
end

local function new_series(title, message, percentage)
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

local function setup(formatter)
    SeriesFormatter = formatter
end

local M = {
    setup = setup,
    new_series = new_series,
}

return M