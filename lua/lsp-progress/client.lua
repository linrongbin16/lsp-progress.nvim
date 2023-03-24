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
    -- deduped tokens
    -- title -> message -> token
    _deduped_tokens = {},
}

function ClientObject:has_series(token)
    return self.serieses[token] ~= nil
end

function ClientObject:_has_dedup_token(title, message)
    title = tostring(title)
    message = tostring(message)
    if not self._deduped_tokens[title] then
        return false
    end
    if not self._deduped_tokens[title][message] then
        return false
    end
    return true
end

function ClientObject:_set_dedup_token(title, message, token)
    title = tostring(title)
    message = tostring(message)
    if not self._deduped_tokens[title] then
        self._deduped_tokens[title] = {}
    end
    self._deduped_tokens[title][message] = token
end

function ClientObject:_remove_dedup_token(title, message)
    title = tostring(title)
    message = tostring(message)
    if not self._deduped_tokens[title] then
        return
    end
    self._deduped_tokens[title][message] = nil
end

function ClientObject:_get_dedup_token(title, message)
    title = tostring(title)
    message = tostring(message)
    return self._deduped_tokens[title][message]
end

function ClientObject:remove_series(token)
    if self:has_series(token) then
        local series = self:get_series(token)
        if
            self:_has_dedup_token(series.title, series.message)
            and self:_get_dedup_token(series.title, series.message) == token
        then
            self:_remove_dedup_token(series.title, series.message)
        end
    end
    self.serieses[token] = nil
    self:format()
end

function ClientObject:get_series(token)
    return self.serieses[token]
end

function ClientObject:add_series(token, series)
    self:_set_dedup_token(series.title, series.message, token)
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
    local series_messages = {}
    local visited_tokens = {}
    for tt, message_tokens in pairs(self._deduped_tokens) do
        for ms, token in pairs(message_tokens) do
            if not visited_tokens[token] then
                if self:has_series(token) then
                    local series = self:get_series(token)
                    local result = series:format_result()
                    logger.debug(
                        "|client.format| Get series %s (deduped key: %s-%s) format result in client %s: %s",
                        series:tostring(),
                        tt,
                        ms,
                        self:tostring(),
                        vim.inspect(series_messages)
                    )
                    table.insert(series_messages, result)
                end
                visited_tokens[token] = true
            end
        end
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