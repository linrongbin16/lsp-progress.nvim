local logger = require("lsp-progress.logger")

local SeriesFormatter = nil
local ClientFormatter = nil
local Spinner = nil

local ClientObject = {
    client_id = nil,
    client_name = nil,
    spin_index = 0,
    serieses = {},
    format_changed = false,
    format_result = nil,
}

function ClientObject:has_series(token)
    return self.serieses[token] ~= nil
end

function ClientObject:remove_series(token)
    self.serieses[token] = nil
    self:_changed()
end

function ClientObject:get_series(token)
    return self.serieses[token]
end

function ClientObject:add_series(token, series)
    self.serieses[token] = series
    self:_changed()
end

function ClientObject:empty()
    return next(self.serieses)
end

function ClientObject:increase_spin_index(spinner_length)
    local old = self.spin_index
    self.spin_index = (self.spin_index + 1) % spinner_length
    logger.debug(
        "Client %s spin index:%d => %d",
        self:tostring(),
        old,
        self.spin_index
    )
    self:_changed()
end

function ClientObject:tostring()
    return string.format("[%s-%d]", self.client_name, self.client_id)
end

function ClientObject:_changed()
    self.format_changed = true
end

-- if s1 is higher priority than s2
local function higher_priority(s1, s2)
    -- s1 has no percentage, so it's higher priority
    if s1.percentage == nil then
        return true
    end

    -- s2 has no percentage, so it's higher priority
    if s2.percentage == nil then
        return false
    end

    -- both s1 and s2 has percentage, lower percentage has higher priority
    return s1.percentage < s2.percentage
end

function ClientObject:format()
    if not self.format_changed then
        return self.format_result
    end

    local deduped_serieses = {}
    for token, series in pairs(self.serieses) do
        -- dedup key: title+message
        local key = series:key()
        if deduped_serieses[key] then
            -- if already has a message with same key,
            -- remove it, choose the one has nil or lower percentage.
            -- since we believe it need more time to complete.
            local old_series = deduped_serieses[key]
            local higher_priority_series = higher_priority(series, old_series)
                    and series
                or old_series
            deduped_serieses[key] = higher_priority_series
            logger.debug(
                "Token %s duplicate by key `%s` in client %s, use series with higher priority (new: %s, old: %s)",
                token,
                key,
                self:tostring(),
                vim.inspect(series.percentage),
                vim.inspect(old_series.percentage)
            )
        else
            deduped_serieses[key] = series
            logger.debug(
                "Token %s with key `%s` first show up in client %s, add it to deduped_serieses",
                token,
                key,
                self:tostring()
            )
        end
    end
    local series_messages = {}
    for _, series in pairs(deduped_serieses) do
        local msg = SeriesFormatter(
            series.title,
            series.message,
            series.percentage,
            series.done
        )
        logger.debug(
            "Format series (client %s): %s",
            self.client_id,
            vim.inspect(msg)
        )
        table.insert(series_messages, msg)
    end
    self.format_result = ClientFormatter(
        self.client_name,
        Spinner[self.spin_index + 1],
        series_messages
    )
    self.format_changed = false
    return self.format_result
end

local function new_client(client_id, client_name)
    local client = vim.tbl_extend(
        "force",
        vim.deepcopy(ClientObject),
        { client_id = client_id, client_name = client_name }
    )
    client:_changed()
    return client
end

local function setup(series_formatter, client_formatter, spinner)
    SeriesFormatter = series_formatter
    ClientFormatter = client_formatter
    Spinner = spinner
end

local M = {
    setup = setup,
    new_client = new_client,
}

return M