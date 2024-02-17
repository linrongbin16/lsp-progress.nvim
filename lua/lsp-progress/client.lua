local logger = require("lsp-progress.logger")

--- @alias lsp_progress.ClientFormatResult string|any|nil
--- @alias lsp_progress.ClientFormat fun(client_name:string,spinner:string,series_messages:string[]|table[]):lsp_progress.ClientFormatResult
--- @type lsp_progress.ClientFormat?
local ClientFormat = nil

--- @type string[]|nil
local Spinner = nil

---@alias lsp_progress.ClientId integer
---@alias lsp_progress.SeriesToken integer|string
---
--- @class lsp_progress.Client
--- @field client_id lsp_progress.ClientId?
--- @field client_name string|nil
--- @field spin_index integer
--- @field serieses table<lsp_progress.SeriesToken, lsp_progress.Series>  map series token => series object.
--- @field private _format_cache lsp_progress.ClientFormatResult
--- @field private _deduped_tokens table<string, lsp_progress.SeriesToken> map: title+message => token.
--- @field private _formatting boolean
local Client = {}

--- @param client_id lsp_progress.ClientId
--- @param client_name string
--- @return lsp_progress.Client
function Client:new(client_id, client_name)
    local o = {
        client_id = client_id,
        client_name = client_name,
        spin_index = 0,
        serieses = {},
        _format_cache = nil,
        _deduped_tokens = {},
        _formatting = false,
    }
    setmetatable(o, self)
    self.__index = self

    o:format()
    -- logger.debug("|client - Client:new| new: %s", vim.inspect(o))

    return o
end

--- @param token lsp_progress.SeriesToken
--- @return boolean
function Client:has_series(token)
    return self.serieses[token] ~= nil
end

--- @package
--- @param title string
--- @param message string
--- @return string
local function _get_dedup_key(title, message)
    return tostring(title) .. "-" .. tostring(message)
end

--- @package
--- @param title string
--- @param message string
--- @return boolean
function Client:_has_dedup_token(title, message)
    return self._deduped_tokens[_get_dedup_key(title, message)] ~= nil
end

--- @package
--- @param title string
--- @param message string
--- @param token lsp_progress.SeriesToken
function Client:_set_dedup_token(title, message, token)
    self._deduped_tokens[_get_dedup_key(title, message)] = token
end

--- @package
--- @param title string
--- @param message string
function Client:_remove_dedup_token(title, message)
    self._deduped_tokens[_get_dedup_key(title, message)] = nil
end

--- @package
--- @param title string
--- @param message string
--- @return lsp_progress.SeriesToken
function Client:_get_dedup_token(title, message)
    return self._deduped_tokens[_get_dedup_key(title, message)]
end

--- @param token lsp_progress.SeriesToken
function Client:remove_series(token)
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

--- @param token lsp_progress.SeriesToken
--- @return lsp_progress.Series
function Client:get_series(token)
    return self.serieses[token]
end

--- @param token lsp_progress.SeriesToken
--- @param series lsp_progress.Series
function Client:add_series(token, series)
    self:_set_dedup_token(series.title, series.message, token)
    self.serieses[token] = series
    self:format()
end

--- @return boolean
function Client:empty()
    return not next(self.serieses) --[[@as boolean]]
end

function Client:increase_spin_index()
    local old = self.spin_index
    assert(type(Spinner) == "table", "Spinner must be a lua table")
    assert(#Spinner > 0, "Spinner length must greater than 0")
    self.spin_index = (self.spin_index + 1) % #Spinner
    -- logger.debug(
    --     "|client.increase_spin_index| client(%s) spin index: %d => %d",
    --     vim.inspect(self),
    --     old,
    --     self.spin_index
    -- )
    self:format()
end

--- @return string
function Client:get_spin_index()
    assert(Spinner ~= nil, "Spinner cannot be nil")
    assert(#Spinner > 0, "Spinner length must greater than 0")
    return Spinner[self.spin_index + 1]
end

--- @return lsp_progress.ClientFormatResult
function Client:format()
    if self._formatting then
        return self._format_cache
    end

    self._formatting = true

    --- @type lsp_progress.SeriesFormatResult[]
    local series_messages = {}

    --- @type table<lsp_progress.SeriesToken, boolean>
    local visited_tokens = {}

    for dedup_key, token in pairs(self._deduped_tokens) do
        if not visited_tokens[token] then
            if self:has_series(token) then
                local ss = self:get_series(token)
                local result = ss:format_result()
                -- logger.debug(
                --     "|client - Client:format| get series %s (deduped key: %s) format result in client %s, series_messages: %s",
                --     vim.inspect(ss),
                --     dedup_key,
                --     vim.inspect(self),
                --     vim.inspect(series_messages)
                -- )
                table.insert(series_messages, result)
            end
            visited_tokens[token] = true
        end
    end

    assert(type(ClientFormat) == "function", "ClientFormat must be a function")

    local ok, result_or_err = pcall(
        ClientFormat,
        self.client_name,
        self:get_spin_index(),
        series_messages
    )

    vim.schedule(function()
        self._formatting = false
    end)

    logger.ensure(
        ok,
        "failed to invoke 'client_format' function with params: %s! error: %s",
        vim.inspect(self),
        vim.inspect(result_or_err)
    )

    self._format_cache = result_or_err
    -- logger.debug("|client - Client:format| format: %s", vim.inspect(self))
    return self._format_cache
end

--- @return lsp_progress.ClientFormatResult
function Client:format_result()
    return self._format_cache
end

--- @param client_format lsp_progress.ClientFormat
--- @param spinner string[]
local function setup(client_format, spinner)
    ClientFormat = client_format
    Spinner = spinner
end

local M = {
    setup = setup,
    Client = Client,
    _get_dedup_key = _get_dedup_key,
}

return M
