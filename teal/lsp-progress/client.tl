local logger = require("lsp-progress.logger")

local record ClientRecord
    id: number|nil
    name: string|nil
    spin_index: integer
    serieses: {string:SeriesRecord}

    -- cached formatted result
    _formatted: string|any|nil
    -- deduped serieses (2-level map: title => message => token)
    _deduped_tokens: {string:{string:string}}
end
local type ClientRecordFormatterType = function(string|nil,string|nil,{string|any}):string|any|nil

local ClientRecordFormatter:ClientRecordFormatterType|nil = nil
local Spinner:{string} = {}

function ClientRecord:formatted_result():string|any|nil
    return self._formatted
end

function ClientRecord:tostring():string
    return string.format("[%s-%s]", tostring(self.name), tostring(self.id))
end

function ClientRecord:has_series(token:string):boolean
    return self.serieses[token] ~= nil
end

function ClientRecord:get_series(token:string):SeriesRecord
    return self.serieses[token]
end

function ClientRecord:format():string|any|nil
    local series_messages:{string|any} = {}
    local visited_tokens:{string:boolean} = {}
    for tt, message_tokens in pairs(self._deduped_tokens) do
        message_tokens = message_tokens as {string:string}
        for ms, token in pairs(message_tokens) do
            if not visited_tokens[token] then
                if self:has_series(token) then
                    local series = self:get_series(token)
                    local result = series:formatted_result()
                    logger.debug(
                        "|client.ClientRecord.format| get series %s (deduped key: %s-%s) format result in client %s: %s",
                        series:tostring(),
                        tt,
                        ms,
                        self:tostring(),
                        vim.inspect(series_messages)
                    )
                    if result then
                        table.insert(series_messages, result as string|any)
                    end
                end
                visited_tokens[token] = true
            end
        end
    end
    if ClientRecordFormatter is ClientRecordFormatterType then
        self._formatted = ClientRecordFormatter(
            self.name,
            Spinner[self.spin_index + 1],
            series_messages
        )
    end
    logger.debug(
        "|client.ClientRecord.format| format client %s: %s",
        self:tostring(),
        vim.inspect(self._formatted)
    )
    return self._formatted
end

function ClientRecord:_has_deduped_token(title:string|nil, message:string|nil):boolean
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

function ClientRecord:_set_deduped_token(title:string|nil, message:string|nil, token:string|nil):nil
    title = tostring(title)
    message = tostring(message)
    if not self._deduped_tokens[title] then
        self._deduped_tokens[title] = {}
    end
    self._deduped_tokens[title][message] = token
end

function ClientRecord:_remove_deduped_token(title:string|nil, message:string|nil):nil
    title = tostring(title)
    message = tostring(message)
    if not self._deduped_tokens[title] then
        return
    end
    self._deduped_tokens[title][message] = nil
end

function ClientRecord:_get_deduped_token(title:string|nil, message:string|nil):string
    title = tostring(title)
    message = tostring(message)
    return self._deduped_tokens[title][message]
end

function ClientRecord:remove_series(token:string|nil):nil
    if self:has_series(token) then
        local series = self:get_series(token)
        if
            self:_has_deduped_token(series.title, series.message)
            and self:_get_deduped_token(series.title, series.message) == token
        then
            self:_remove_deduped_token(series.title, series.message)
        end
    end
    self.serieses[token] = nil
    self:format()
end

function ClientRecord:add_series(token:string|nil, series:SeriesRecord):nil
    self:_set_deduped_token(series.title, series.message, token)
    self.serieses[token] = series
    self:format()
end

function ClientRecord:empty():boolean
    return next(self.serieses) as boolean
end

function ClientRecord:increase_spin_index():nil
    local old = self.spin_index
    self.spin_index = (self.spin_index + 1) % #Spinner
    logger.debug(
        "|client.ClientRecord.increase_spin_index| client %s spin index:%d => %d",
        self:tostring(),
        old,
        self.spin_index as integer
    )
    self:format()
end

local function setup(client_formatter:ClientRecordFormatterType, spinner:{string}):nil
    ClientRecordFormatter = client_formatter
    Spinner = spinner
end

local function new_client(id:number, name:string):ClientRecord
    local self:ClientRecord = setmetatable({}, { __index = ClientRecord })
    self.id = id
    self.name = name
    self.spin_index = 0
    self.serieses = {}
    self._formatted = nil
    self._deduped_tokens = {}
    self:format()
    return self
end

local M:table = {
    setup = setup,
    new_client = new_client,
}

return M
