local SeriesObject = {
    token = nil,
    title = nil,
    message = nil,
    percentage = nil,
    done = false,

    -- format cache
    _format_cache = nil,

    -- key
    key = nil,
}

local SeriesFormatter = nil

function SeriesObject:update(message, percentage)
    self.message = message
    self.percentage = percentage
    self:_format()
end

function SeriesObject:finish(message)
    self.message = message
    self.percentage = 100
    self.done = true
    self:_format()
end

function SeriesObject:key()
    return self.key
end

function SeriesObject:priority()
    if self.percentage == nil then
        return -1
    else
        return self.percentage
    end
end

function SeriesObject:_format()
    self._format_cache =
        SeriesFormatter(self.title, self.message, self.percentage, self.done)
end

function SeriesObject:format_result()
    return self._format_cache
end

local function new_series(token, title, message, percentage)
    local series = vim.tbl_extend("force", vim.deepcopy(SeriesObject), {
        token = token,
        title = title,
        message = message,
        percentage = percentage,
        done = false,
    })
    series.key = tostring(title) .. "-" .. tostring(message)
    series:_format()
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