local logger = require("lsp-progress.logger")

local ClientFormatter = nil
local Spinner = nil

local DedupedSeriesCacheObject = {
    token = nil,
    all_tokens = nil,
    tokens_count = nil,
}

local function new_deduped_series_cache_object()
    local cache = vim.tbl_extend(
        "force",
        vim.deepcopy(DedupedSeriesCacheObject),
        { all_tokens = {}, tokens_count = 0 }
    )
    return cache
end

function DedupedSeriesCacheObject:tostring()
    return string.format(
        "<DedupedSeries token:%s, all_tokens:%s, tokens_count:%s>",
        vim.inspect(self.token),
        vim.inspect(vim.all_tokens),
        vim.inspect(self.tokens_count)
    )
end

function DedupedSeriesCacheObject:add_dedup(client, series)
    -- add token if not exist
    if self.all_tokens[series.token] == nil then
        self.all_tokens[series.token] = true
        self.tokens_count = self.tokens_count + 1
    end
    -- update token to the deduped one series if it's lower priority
    if self.token and client:has_series(self.token) then
        local old_series = client:get_series(self.token)
        if series:priority() < old_series:priority() then
            logger.debug(
                "Use new series (token: %s, key: %s) to replace old series (token: %s) in deduped series cache on client %s: %s",
                series.token,
                series.key,
                old_series.token,
                client:tostring(),
                self:tostring()
            )
            self.token = series.token
        end
    else
        logger.debug(
            "Add new series (token: %s, key: %s) in deduped series cache on client %s: %s",
            series.token,
            series.key,
            client:tostring(),
            self:tostring()
        )
        self.token = series.token
    end
    logger.debug(
        "After add new series (token: %s, key: %s) in deduped series cache on client %s: %s",
        series.token,
        series.key,
        client:tostring(),
        self:tostring()
    )
end

function DedupedSeriesCacheObject:remove_dedup(client, series)
    -- remove token if it's exist
    if self.all_tokens[series.token] then
        self.all_tokens[series.token] = nil
        self.tokens_count = vim.fn.max({ self.tokens_count - 1, 0 })
    end

    -- update the lowest priority to the deduped one series
    local min_priority = nil
    local min_series = nil
    for t, _ in pairs(self.all_tokens) do
        if client:has_series(t) then
            local s = client:get_series(t)
            if min_priority == nil or s:priority() < min_priority then
                min_priority = s:priority()
                min_series = s
            end
        end
    end
    self.token = min_series
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

function ClientObject:_has_deduped_series_cache(key)
    return self._deduped_serieses_cache[key] ~= nil
end

function ClientObject:_get_deduped_series_cache(key)
    return self._deduped_serieses_cache[key]
end

function ClientObject:_add_deduped_series_cache(key)
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
        if self:_has_deduped_series_cache(key) then
            local deduped_series_cache = self:_get_deduped_series_cache(key)
            deduped_series_cache:remove_dedup(self, series)
            if deduped_series_cache.tokens_count <= 0 then
                self:_remove_deduped_series(key)
                logger.debug(
                    "Remove series (token %s) from deduped series cache (key %s) on client %s",
                    token,
                    key,
                    self:tostring()
                )
            end
        end
    end
    self.serieses[token] = nil
    self:format()
end

function ClientObject:add_series(series)
    local key = series.key
    if not self:_has_deduped_series_cache(key) then
        self:_add_deduped_series_cache(key)
        logger.debug(
            "Add deduped series cache (key %s) to client %s: %s",
            key,
            self:tostring(),
            self:_get_deduped_series_cache(key):tostring()
        )
    end
    local deduped_series_cache = self:_get_deduped_series_cache(key)
    deduped_series_cache:add_dedup(self, series)
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