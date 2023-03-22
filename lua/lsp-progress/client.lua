local logger = require("lsp-progress.logger")

local ClientFormatter = nil
local Spinner = nil

local DedupedSeriesCacheObject = {
    token = nil,
    all_tokens = {},
    count = nil,
}

local function new_deduped_series_cache_object()
    local cache = vim.tbl_extend(
        "force",
        vim.deepcopy(DedupedSeriesCacheObject),
        { count = 0 }
    )
    return cache
end

function DedupedSeriesCacheObject:add_dedup(client, series)
    local token = series.token
    if not client:has_series(token) then
        self.token = token
        self.all_tokens[token] = true
        self.count = self.count + 1
    else
        local old_series = client:get_series(token)
        if series:less_than(old_series) then
            self.token = token
        end
        self.all_tokens[token] = true
        self.count = self.count + 1
    end
end

function DedupedSeriesCacheObject:remove_dedup(client, series)
    local token = series.token
    if self.all_tokens[token] then
        self.all_tokens[token] = nil
        self.count = vim.fn.max(self.count - 1, 0)
        local min_priority = nil
        local min_token = nil
        for t, v in pairs(self.all_tokens) do
            if t and v and client:has_series(t) then
                local next_series = client:get_series(t)
                if
                    min_priority == nil
                    or next_series:priority() < min_priority
                then
                    min_priority = next_series:priority()
                    min_token = t
                end
            end
        end
        self.token = min_token
    end
end

local ClientObject = {
    client_id = nil,
    client_name = nil,
    spin_index = 0,
    serieses = {},

    -- format cache
    _format_cache = nil,
    -- deduped series cache
    _deduped_serieses_cache = {},
}

function ClientObject:_has_deduped_series(key)
    return self._deduped_serieses_cache[key] ~= nil
end

function ClientObject:_get_deduped_series(key)
    return self._deduped_serieses_cache[key]
end

function ClientObject:_add_deduped_series(key)
    self._deduped_serieses_cache[key] = new_deduped_series_cache_object()
end

function ClientObject:_remove_deduped_series(key)
    self._deduped_serieses_cache[key] = nil
end

function ClientObject:has_series(token)
    return self.serieses[token] ~= nil
end

function ClientObject:remove_series(token)
    if self:has_series(token) then
        local series = self:get_series(token)
        local key = series.key
        if self:_has_deduped_series(key) then
            local deduped_series = self:_get_deduped_series(key)
            deduped_series:remove_dedup(self, series)
            if deduped_series.count <= 0 then
                self:_remove_deduped_series(key)
            end
        end
    end
    self.serieses[token] = nil
    self:format()
end

function ClientObject:get_series(token)
    return self.serieses[token]
end

function ClientObject:add_series(token, series)
    if not self:has_series(token) then
        local key = series.key
        if not self:_has_deduped_series(key) then
            local deduped_series = self:_get_deduped_series(key)
            deduped_series:remove_dedup(self, series)
            if deduped_series.count <= 0 then
                self:_remove_deduped_series(key)
            end
        end
    end
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
        "Client %s spin index:%d => %d",
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
        local msg = series:format_result()
        logger.debug(
            "Format series (client %s): %s",
            self.client_id,
            vim.inspect(msg)
        )
        table.insert(series_messages, msg)
    end
    self._format_cache = ClientFormatter(
        self.client_name,
        Spinner[self.spin_index + 1],
        series_messages
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