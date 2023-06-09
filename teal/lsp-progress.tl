local logger = require("lsp-progress.logger")
local defaults = require("lsp-progress.defaults")
local SeriesRecord = require('lsp-progress.series').SeriesRecord
local ClientRecord = require('lsp-progress.client').ClientRecord

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
        vim.cmd("doautocmd User " .. Config.event)
        vim.defer_fn(reset_event, Config.event_update_time_limit)
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

local function register_client(id:number, name:string):nil
    if not has_client(id) then
        LspClients[id] = ClientRecord.new(id, name)
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

local function progress_handler(err:table, msg:table, ctx:table):nil
    local client_id = ctx.client_id
    local nvim_lsp_client = vim.lsp.get_client_by_id(client_id)
    local client_name = nvim_lsp_client and nvim_lsp_client.name or "unknown"

    -- register client id if not exist
    register_client(client_id, client_name)

    local value = msg.value
    local token = msg.token

    local client = get_client(client_id)
    if value.kind == "begin" then
        -- add task
        local series = SeriesRecord.new(value.title, value.message, value.percentage)
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
        local msg = client:formatted_result()
        if msg and msg ~= "" then
            table.insert(client_messages, msg)
            logger.debug(
                "|lsp-progress.progress| get client %s format result: %s",
                client:tostring(),
                vim.inspect(client_messages)
            )
        end
    end
    local content = option.format(client_messages)
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

local function setup(option)
    -- setup config
    Config = defaults.setup(option)

    -- setup logger
    logger.setup(
        Config.debug as boolean,
        Config.console_log as boolean,
        Config.file_log as boolean,
        Config.file_log_name as string|nil
    )

    -- setup series
    require("lsp-progress.series").setup(Config.series_format)

    -- init client
    require("lsp-progress.client").setup(Config.client_format, Config.spinner)

    if not Registered then
        if vim.lsp.handlers["$/progress"] then
            local old_handler = vim.lsp.handlers["$/progress"]
            vim.lsp.handlers["$/progress"] = function(...:table)
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

