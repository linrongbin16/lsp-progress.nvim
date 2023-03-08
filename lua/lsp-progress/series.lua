local SeriesObject = {
    title = nil,
    message = nil,
    percentage = nil,
    done = false,
}

function SeriesObject:update(message, percentage)
    self.message = message
    self.percentage = percentage
end

function SeriesObject:finish(message)
    self.message = message
    self.percentage = 100
    self.done = true
end

function SeriesObject:key()
    return tostring(self.title) .. "-" .. tostring(self.message)
end

local function new_series(title, message, percentage)
    local series = vim.tbl_extend("force", vim.deepcopy(SeriesObject), {
        title = title,
        message = message,
        percentage = percentage,
        done = false,
    })
    return series
end

local M = {
    new_series = new_series,
}

return M
