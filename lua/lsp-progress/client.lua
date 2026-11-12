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

--- Build the dedup key of a series from its title and message.
---
--- The title length is prefixed to the key, so a title can never be confused
--- with a part of the message: `("a-b", "c")` and `("a", "b-c")` produce
--- different keys.
--- @param title string?
--- @param message string?
--- @return string
local function _get_dedup_key(title, message)
    title = tostring(title)
    return string.format("%d:%s:%s", #title, title, tostring(message))
end

--- @param token lsp_progress.SeriesToken
function Client:remove_series(token)
    self.serieses[token] = nil
    if self:empty() then
        self.serieses = {}
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

--- @param series lsp_progress.Series
--- @return integer
local function _series_priority(series)
    return series.percentage or -1
end

--- @return lsp_progress.ClientFormatResult
function Client:format()
    if self._formatting then
        return self._format_cache
    end

    self._formatting = true

    --- @type lsp_progress.SeriesFormatResult[]
    local series_messages = {}

    -- Dedup the series that have the same title and message on the fly. The
    -- dedup map is rebuilt on every format, so it can never grow unboundedly
    -- nor keep stale entries of updated/removed series.
    --- @type table<string, lsp_progress.Series>
    local deduped_serieses = {}

    for _, series in pairs(self.serieses) do
        local key = _get_dedup_key(series.title, series.message)
        local old_series = deduped_serieses[key]
        if
            not old_series
            or _series_priority(series) < _series_priority(old_series)
        then
            -- keep the series that needs more time to complete.
            deduped_serieses[key] = series
        end
    end

    for _, series in pairs(deduped_serieses) do
        table.insert(series_messages, series:format_result())
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
