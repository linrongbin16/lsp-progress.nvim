--- @type table<string, function>
local logger = require("lsp-progress.logger")

--- @alias ClientFormatterType fun(client_name:string,spinner:string,series_messages:string[]|table[]):string|table|nil

--- @type ClientFormatterType|nil
local ClientFormatter = nil

--- @type string[]|nil
local Spinner = nil

--- @alias ClientFormatResult string|table|nil

--- @class ClientObject
--- @field client_id integer|nil
--- @field client_name string|nil
--- @field spin_index integer
--- @field serieses table<string, SeriesObject>
---     map: key => SeriesObject.
--- @field private _format_cache ClientFormatResult
---     formatted cache.
--- @field private _deduped_tokens table<string, string>
---     deduped tokens, map: title+message => token.
local ClientObject = {
    client_id = nil,
    client_name = nil,
    spin_index = 0,
    serieses = {},

    -- format cache
    _format_cache = nil,
    -- deduped tokens
    _deduped_tokens = {},
}

--- @param token string
--- @return boolean
function ClientObject:has_series(token)
    return self.serieses[token] ~= nil
end

--- @package
--- @param title string
--- @param message string
--- @return string
local function get_dedup_key(title, message)
    return tostring(title) .. "-" .. tostring(message)
end

--- @package
--- @param title string
--- @param message string
--- @return boolean
function ClientObject:_has_dedup_token(title, message)
    return self._deduped_tokens[get_dedup_key(title, message)] ~= nil
end

--- @package
--- @param title string
--- @param message string
--- @param token string
--- @return nil
function ClientObject:_set_dedup_token(title, message, token)
    self._deduped_tokens[get_dedup_key(title, message)] = token
end

--- @package
--- @param title string
--- @param message string
--- @return nil
function ClientObject:_remove_dedup_token(title, message)
    self._deduped_tokens[get_dedup_key(title, message)] = nil
end

--- @package
--- @param title string
--- @param message string
--- @return string token
function ClientObject:_get_dedup_token(title, message)
    return self._deduped_tokens[get_dedup_key(title, message)]
end

--- @param token string
--- @return nil
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
    if self:empty() then
        self.serieses = {}
        self._deduped_tokens = {}
    end
    self:format()
end

--- @param token string
--- @return SeriesObject
function ClientObject:get_series(token)
    return self.serieses[token]
end

--- @param token string
--- @param series SeriesObject
--- @return nil
function ClientObject:add_series(token, series)
    self:_set_dedup_token(series.title, series.message, token)
    self.serieses[token] = series
    self:format()
end

--- @return boolean
function ClientObject:empty()
    return not next(self.serieses) --[[@as boolean]]
end

--- @return nil
function ClientObject:increase_spin_index()
    --- @type integer
    local old = self.spin_index
    assert(Spinner ~= nil, "Spinner cannot be nil")
    assert(#Spinner > 0, "Spinner length cannot be 0")
    --- @type integer
    self.spin_index = (self.spin_index + 1) % #Spinner
    logger.debug(
        "|client.increase_spin_index| client %s spin index:%d => %d",
        self:tostring(),
        old,
        self.spin_index
    )
    self:format()
end

--- @return string
function ClientObject:tostring()
    return string.format("[%s-%d]", self.client_name, self.client_id)
end

--- @return ClientFormatResult
function ClientObject:format()
    --- @type SeriesFormatResult[]
    local series_messages = {}
    --- @type table<string, boolean>
    local visited_tokens = {}
    for dedup_key, token in pairs(self._deduped_tokens) do
        if not visited_tokens[token] then
            if self:has_series(token) then
                --- @type SeriesObject
                local series = self:get_series(token)
                --- @type SeriesFormatResult
                local result = series:format_result()
                logger.debug(
                    "|client.format| Get series %s (deduped key: %s) format result in client %s: %s",
                    series:tostring(),
                    dedup_key,
                    self:tostring(),
                    vim.inspect(series_messages)
                )
                table.insert(series_messages, result)
            end
            visited_tokens[token] = true
        end
    end
    assert(Spinner ~= nil, "Spinner cannot be nil")
    assert(#Spinner > 0, "Spinner length cannot be 0")
    assert(ClientFormatter ~= nil, "ClientFormatter cannot be null")
    local ok, result = pcall(
        ClientFormatter,
        self.client_name,
        Spinner[self.spin_index + 1],
        series_messages
    )

    if not ok then
        logger.throw(
            "failed to invoke 'client_format'! error: %s, params: %s, %s, %s",
            vim.inspect(result),
            vim.inspect(self.client_name),
            vim.inspect(Spinner[self.spin_index + 1]),
            vim.inspect(series_messages)
        )
    end
    self._format_cache = result

    logger.debug(
        "|client.format| format client %s: %s",
        self:tostring(),
        vim.inspect(self._format_cache)
    )
    return self._format_cache
end

--- @return ClientFormatResult
function ClientObject:format_result()
    return self._format_cache
end

--- @param client_id integer
--- @param client_name string
--- @return ClientObject
local function new_client(client_id, client_name)
    --- @type ClientObject
    local client = vim.tbl_extend(
        "force",
        vim.deepcopy(ClientObject),
        { client_id = client_id, client_name = client_name }
    )
    client:format()
    return client
end

--- @param client_formatter ClientFormatterType
--- @param spinner string[]
--- @return nil
local function setup(client_formatter, spinner)
    ClientFormatter = client_formatter
    Spinner = spinner
end

--- @type table<string, function>
local M = {
    --- @overload fun(client_formatter:ClientFormatterType, spinner:string[]):nil
    setup = setup,
    --- @overload fun(client_id:integer, client_name:string):ClientObject
    new_client = new_client,
}

return M
