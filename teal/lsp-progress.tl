global record SeriesRecord
    title: string|nil
    message: string|nil
    percentage: number|nil
    done: boolean
    _formatted: string|any|nil

    tostring: function(SeriesRecord):string
    format: function(SeriesRecord):string|any|nil
    formatted_result: function(SeriesRecord):string|any|nil
    update: function(SeriesRecord, string|nil, number|nil):nil
    finish: function(SeriesRecord, string|nil):nil
end

global record ClientRecord
    id: number|nil
    name: string|nil
    spin_index: integer
    serieses: {string:SeriesRecord}
    _formatted: string|any|nil
    _deduped_tokens: {string:{string:string}}

    formatted_result: function(ClientRecord):string|any|nil
    tostring: function(ClientRecord):string
    has_series: function(ClientRecord, string):boolean
    get_series: function(ClientRecord, string):SeriesRecord
    format: function(ClientRecord):string|any|nil
    _has_deduped_token: function(ClientRecord, string|nil, string|nil):boolean
    _set_deduped_token: function(ClientRecord, string|nil, string|nil, token:string|nil):nil
    _remove_deduped_token: function(ClientRecord, string|nil, string|nil):nil
    _get_deduped_token: function(ClientRecord, string|nil, string|nil):string
    remove_series: function(ClientRecord, string|nil):nil
    add_series: function(ClientRecord, string|nil, SeriesRecord):nil
    empty: function(ClientRecord):boolean
    increase_spin_index: function(ClientRecord):nil
end

global type SeriesRecordFormatterType = function(string|nil,string|nil,number|nil,boolean|nil):string|any|nil
global type ClientRecordFormatterType = function(string|nil,string|nil,{string|any}):string|any|nil

local logger = require("lsp-progress.logger")
local new_series = require("lsp-progress.series").new_series as function(string|nil, string|nil, number|nil):SeriesRecord
local new_client = require("lsp-progress.client").new_client as function(number,string):ClientRecord

local Config:table = {}
local Registered = false
-- map: id => client
local LspClients:{number:ClientRecord} = {}
local EventEmitted = false

-- {
-- Event

local function reset_event():nil
    EventEmitted = false
end

local function emit_event():nil
    if not EventEmitted then
        EventEmitted = true
        vim.cmd("doautocmd User " .. Config.event as string)
        vim.defer_fn(reset_event, Config.event_update_time_limit as integer)
        logger.debug("|lsp-progress.emit_event| emit user event:%s", Config.event)
    end
end

-- }

-- {
-- Clients

local function has_client(id:number|nil):boolean
    return LspClients[id] ~= nil
end

local function get_client(id:number):ClientRecord
    return LspClients[id]
end

local function remove_client(id:number):nil
    LspClients[id] = nil
end

local function register_client(id:integer, name:string):nil
    if not has_client(id) then
        LspClients[id] = new_client(id, name)
        logger.debug(
            "|lsp-progress.register_client| register client %s",
            get_client(id):tostring()
        )
    end
end

-- }

local function spin(id:number, token:string):nil
    local function spin_again()
        spin(id, token)
    end

    -- check client exist
    if not has_client(id) then
        logger.debug(
            "|lsp-progress.spin| client id %d not found, stop spin",
            id 
        )
        return
    end

    -- check token exist
    local client = get_client(id)
    if not client:has_series(token) then
        logger.debug(
            "|lsp-progress.spin| token %s not found in client %s, stop spin",
            token,
            client:tostring()
        )
        return
    end

    client:increase_spin_index()
    vim.defer_fn(spin_again, Config.spin_update_time as integer)

    local series = client:get_series(token)
    -- if series done, remove this series from client later
    if series.done then
        vim.defer_fn(function()
            -- check client id again
            if not has_client(id) then
                logger.debug(
                    "|lsp-progress.spin| client id %d not found, stop remove series",
                    id
                )
                emit_event()
                return
            end
            local client2 = get_client(id)
            -- check token again
            if not client2:has_series(token) then
                logger.debug(
                    "|lsp-progress.spin| token %s not found in client %s, stop remove series",
                    token,
                    client2:tostring()
                )
                emit_event()
                return
            end
            client2:remove_series(token)
            logger.debug(
                "|lsp-progress.spin| token %s has been removed from client %s since it's done",
                token,
                client2:tostring()
            )
            if client2:empty() then
                -- if client2 is empty, also remove it from Clients
                remove_client(id)
                logger.debug(
                    "|lsp-progress.spin| client %s has been removed from since it's empty",
                    client2:tostring()
                )
            end
            emit_event()
        end, Config.decay as integer)
        logger.debug(
            "|lsp-progress.spin| token %s is done in client %s, remove series later...",
            token,
            client:tostring()
        )
    end
    -- if client is stopped, remove this client later
    if vim.lsp.client_is_stopped(id) then
        vim.defer_fn(function()
            -- check client id again
            if not has_client(id) then
                logger.debug(
                    "|lsp-progress.spin| client id %d not found, stop remove series",
                    id
                )
                emit_event()
                return
            end
            -- if this client is stopped, remove it from Clients
            remove_client(id)
            logger.debug(
                "|lsp-progress.spin| client id %d has been removed from since it's stopped",
                id
            )
            emit_event()
        end, Config.decay as integer)
        logger.debug(
            "|lsp-progress.spin| client id %d is stopped, remove it later...",
            id
        )
    end

    -- notify user to refresh UI
    emit_event()
end

local type MessageValueRecord = record
    kind: string
    title: string|nil
    message: string|nil
    percentage: number|nil
end

local function progress_handler(err:table, msg:table, ctx:table):nil
    local client_id = ctx.client_id as integer
    local nvim_lsp_client = vim.lsp.get_client_by_id(client_id)
    local client_name = nvim_lsp_client and nvim_lsp_client.name as string or "unknown"

    -- register client id if not exist
    register_client(client_id, client_name)

    local value = msg.value as MessageValueRecord
    local token = msg.token as string

    local client = get_client(client_id)
    if value.kind == "begin" then
        -- add task
        local series = new_series(value.title, value.message, value.percentage)
        client:add_series(token, series)
        -- start spin, it will also notify user at a fixed rate
        spin(client_id, token)
        logger.debug(
            "|lsp-progress.progress_handler| add new series to client %s: %s",
            client:tostring(),
            series:tostring()
        )
    elseif value.kind == "report" then
        local series = client:get_series(token)
        if series then
            series:update(value.message, value.percentage)
            client:add_series(token, series)
            logger.debug(
                "|lsp-progress.progress_handler| update series in client %s: %s",
                client:tostring(),
                series:tostring()
            )
        else
            logger.debug(
                "|lsp-progress.progress_handler| series (token: %s) not found in client %s when updating",
                token,
                client:tostring()
            )
        end
    else
        if value.kind ~= "end" then
            logger.warn(
                "|lsp-progress.progress_handler| unknown message kind `%s` from client %s",
                value.kind,
                client:tostring()
            )
        end
        if client:has_series(token) then
            local series = client:get_series(token)
            series:finish(value.message)
            client:format()
            logger.debug(
                "|lsp-progress.progress_handler| series done in client %s: %s",
                client:tostring(),
                series:tostring()
            )
        else
            logger.debug(
                "|lsp-progress.progress_handler| series (token: %s) not found in client %s when ending",
                token,
                client:tostring()
            )
        end
    end

    -- notify user to refresh UI
    emit_event()
end

local function progress(option:table):string|nil
    option = vim.tbl_deep_extend("force", vim.deepcopy(Config), option or {})

    local active_clients_count:number = #vim.lsp.get_active_clients()
    if active_clients_count <= 0 then
        return ""
    end

    local client_messages = {}
    for _, client in pairs(LspClients) do
        local msg = client:formatted_result() as string|any
        if msg and msg ~= "" then
            table.insert(client_messages, msg)
            logger.debug(
                "|lsp-progress.progress| get client %s format result: %s",
                client:tostring(),
                vim.inspect(client_messages)
            )
        end
    end
    local option_format = option.format as function({string|any}):string|nil
    local content = option_format(client_messages)
    logger.debug(
        "|lsp-progress.progress| progress format: %s",
        vim.inspect(content)
    )
    if option.max_size as integer >= 0 then
        if vim.fn.strdisplaywidth(content) > option.max_size as integer then
            content = vim.fn.strcharpart(
                content,
                0,
                vim.fn.max({ option.max_size as integer - 1, 0 })
            ) .. "…"
        end
    end
    return content
end

local function setup(option:table):nil
    -- setup config
    local defaults_setup = require("lsp-progress.defaults").setup as function(table):table
    Config = defaults_setup(option) as table

    -- setup logger
    logger.setup(
        Config.debug as boolean,
        Config.console_log as boolean,
        Config.file_log as boolean,
        Config.file_log_name as string|nil
    )

    -- setup series
    local series_setup = require("lsp-progress.series").setup as function(SeriesRecordFormatterType):SeriesRecord
    series_setup(Config.series_format as SeriesRecordFormatterType)

    -- init client
    local client_setup = require("lsp-progress.client").setup as function(ClientRecordFormatterType,{string}):ClientRecord
    client_setup(Config.client_format as ClientRecordFormatterType, Config.spinner as {string})

    if not Registered then
        if vim.lsp.handlers["$/progress"] then
            local old_handler = vim.lsp.handlers["$/progress"] as function(...:table):nil
            vim.lsp.handlers["$/progress"] = function(...:table):nil
                old_handler(...)
                progress_handler(...)
            end
        else
            vim.lsp.handlers["$/progress"] = progress_handler
        end
        Registered = true
    end
end

local M = {
    setup = setup,
    progress = progress,
}

return M

