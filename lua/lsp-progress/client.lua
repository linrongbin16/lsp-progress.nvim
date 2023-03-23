local logger = require("lsp-progress.logger")

local ClientFormatter = nil
local Spinner = nil

local ClientObject = {
    client_id = nil,
    client_name = nil,
    spin_index = 0,
    serieses = {},

    -- format cache
    _format_cache = nil,
}

function ClientObject:has_series(token)
    return self.serieses[token] ~= nil
end

function ClientObject:remove_series(token)
    self.serieses[token] = nil
    self:format()
end

function ClientObject:get_series(token)
    return self.serieses[token]
end

function ClientObject:add_series(token, series)
    self.serieses[token] = series
    self:format()
end

function ClientObject:empty()
    return next(self.serieses)
end

function ClientObject:increase_spin_index(spinner_length)
    local old = self.spin_index
    self.spin_index = (self.spin_index + 1) % spinner_length
    logger.debug(
        "|client.increase_spin_index| Client %s spin index:%d => %d",
        self:tostring(),
        old,
        self.spin_index
    )
    self:format()
end

function ClientObject:tostring()
    return string.format("[%s-%d]", self.client_name, self.client_id)
end

function ClientObject:format()
    local deduped_serieses = {}
    for token, series in pairs(self.serieses) do
        -- dedup key: title+message
        local key = series:key()
        if deduped_serieses[key] then
            -- if already has a message with same key,
            -- remove it, choose the one has nil or lower percentage.
            -- since we believe it need more time to complete.
            local old_series = deduped_serieses[key]
            local new_series = series:priority() < old_series:priority()
                    and series
                or old_series
            deduped_serieses[key] = new_series
            logger.debug(
                "|client.format| Token %s duplicate by key `%s` in client %s, use series with higher priority (new: %s, old: %s)",
                token,
                key,
                self:tostring(),
                series:tostring(),
                old_series:tostring()
            )
        else
            deduped_serieses[key] = series
            logger.debug(
                "|client.format| Token %s with key `%s` first show up in client %s, add it to deduped_serieses (new: %s)",
                token,
                key,
                self:tostring(),
                series:tostring()
            )
        end
    end
    local series_messages = {}
    for _, series in pairs(deduped_serieses) do
        local msg = series:format_result()
        logger.debug(
            "|client.format| Get series %s format result in client %s: %s",
            series:tostring(),
            self:tostring(),
            vim.inspect(series_messages)
        )
        table.insert(series_messages, msg)
    end
    self._format_cache = ClientFormatter(
        self.client_name,
        Spinner[self.spin_index + 1],
        series_messages
    )
    logger.debug(
        "|client.format| Format client %s: %s",
        self:tostring(),
        vim.inspect(self._format_cache)
    )
    return self._format_cache
end

function ClientObject:format_result()
    return self._format_cache
end

local function new_client(client_id, client_name)
    local client = vim.tbl_extend(
        "force",
        vim.deepcopy(ClientObject),
        { client_id = client_id, client_name = client_name }
    )
    client:format()
    return client
end

local function setup(client_formatter, spinner)
    ClientFormatter = client_formatter
    Spinner = spinner
end

local M = {
    setup = setup,
    new_client = new_client,
}

return M