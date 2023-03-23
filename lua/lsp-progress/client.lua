local logger = require("lsp-progress.logger")

local ClientFormatter = nil
local Spinner = nil

local DedupedSeriesCacheObject = {
    token = nil,
}

local function new_deduped_series_cache_object()
    local cache =
        vim.tbl_extend("force", vim.deepcopy(DedupedSeriesCacheObject), {})
    return cache
end

function DedupedSeriesCacheObject:assign_dedup(client, series)
    local token = series.token
    if not client:has_series(token) then
        self.token = token
        logger.debug(
            "Add new series (token: %s) to deduped series cache on client %s",
            token,
            client:tostring()
        )
    else
        local old_series = client:get_series(token)
        if series:priority() < old_series:priority() then
            logger.debug(
                "Use new series (token: %s) instead of old series (token: %s) in deduped series cache on client %s",
                token,
                old_series.token,
                client:tostring()
            )
            self.token = token
        end
    end
    logger.debug(
        "After add new series (token: %s) in deduped series cache on client %s",
        token,
        client:tostring()
    )
end

function DedupedSeriesCacheObject:remove_dedup(client, series)
    if self.token == series.token then
        self.token = nil
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

function ClientObject:get_series(token)
    return self.serieses[token]
end

function ClientObject:remove_series(token)
    if self:has_series(token) then
        local series = self:get_series(token)
        local key = series.key
        if self:_has_deduped_series(key) then
            local deduped_series = self:_get_deduped_series(key)
            deduped_series:remove_dedup(self, series)
            self:_remove_deduped_series(key)
            logger.debug(
                "Remove series (token %s) from deduped series cache (key %s) on client %s",
                token,
                key,
                self:tostring()
            )
        end
    end
    self.serieses[token] = nil
    self:format()
end

function ClientObject:add_series(series)
    local key = series.key
    if not self:_has_deduped_series(key) then
        self:_add_deduped_series(key)
        logger.debug(
            "Add deduped series cache (key %s) to client %s",
            key,
            self:tostring()
        )
    end
    local deduped_series = self:_get_deduped_series(key)
    deduped_series:assign_dedup(self, series)
    logger.debug(
        "Add series (token %s) to deduped series cache (key %s) on client %s",
        self.token,
        key,
        self:tostring()
    )
    self.serieses[series.token] = series
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
    local series_messages = {}
    for _, deduped_series in pairs(self._deduped_serieses_cache) do
        local token = deduped_series.token
        if self:has_series(token) then
            local series = self:get_series(token)
            local msg = series:format_result()
            logger.debug(
                "Format series (client %s, token %s): %s",
                self:tostring(),
                token,
                vim.inspect(msg)
            )
            table.insert(series_messages, msg)
        end
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