--- @type table<string, function>
local logger = require("lsp-progress.logger")
--- @type table<string, function>
local defaults = require("lsp-progress.defaults")
--- @type table<string, function>
local event = require("lsp-progress.event")
--- @overload fun(title:string|nil, message:string, percentage:integer|nil,protocol:Protocol):SeriesObject
local new_series = require("lsp-progress.series").new_series
--- @overload fun(client_id:integer, client_name:string):ClientObject
local new_client = require("lsp-progress.client").new_client

-- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#progress
-- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#window_showMessage
local Protocol = require("lsp-progress.protocol")

--- @string
local WINDOW_SHOW_MESSAGE_TOKEN =
    require("lsp-progress.series").WINDOW_SHOW_MESSAGE_TOKEN

-- global variable

--- @type table<string, any>
local Config = {}
--- @type boolean
local Registered = false
--- @type table<integer, ClientObject>
local LspClients = {}

-- client utils

--- @param client_id integer
--- @return boolean
local function has_client(client_id)
    return LspClients[client_id] ~= nil
end

--- @param client_id integer
--- @return ClientObject
local function get_client(client_id)
    return LspClients[client_id]
end

--- @param client_id integer
--- @return nil
local function remove_client(client_id)
    LspClients[client_id] = nil
end

--- @param client_id integer
--- @param client_name string
--- @return nil
local function register_client(client_id, client_name)
    if not has_client(client_id) then
        LspClients[client_id] = new_client(client_id, client_name)
        logger.debug(
            "|lsp-progress.register_client| Register client %s",
            get_client(client_id):tostring()
        )
    end
end

--- @param client_id integer
--- @param token string
--- @return nil
local function spin(client_id, token)
    --- @return nil
    local function spin_again()
        spin(client_id, token)
    end

    -- check client exist
    if not has_client(client_id) then
        logger.debug(
            "|lsp-progress.spin| Client id %d not found, stop spin",
            client_id
        )
        return
    end

    -- check token exist
    local client = get_client(client_id)
    if not client:has_series(token) then
        logger.debug(
            "|lsp-progress.spin| Token %s not found in client %s, stop spin",
            token,
            client:tostring()
        )
        return
    end

    client:increase_spin_index()
    vim.defer_fn(spin_again, Config.spin_update_time)

    local series = client:get_series(token)
    -- if series done, remove this series from client later
    if series.done then
        vim.defer_fn(function()
            -- check client id again
            if not has_client(client_id) then
                logger.debug(
                    "|lsp-progress.spin| Client id %d not found, stop remove series",
                    client_id
                )
                event.emit()
                return
            end
            local client2 = get_client(client_id)
            -- check token again
            if not client2:has_series(token) then
                logger.debug(
                    "|lsp-progress.spin| Token %s not found in client %s, stop remove series",
                    token,
                    client2:tostring()
                )
                event.emit()
                return
            end
            client2:remove_series(token)
            logger.debug(
                "|lsp-progress.spin| Token %s has been removed from client %s since it's done",
                token,
                client2:tostring()
            )
            if client2:empty() then
                -- if client2 is empty, also remove it from Clients
                remove_client(client_id)
                logger.debug(
                    "|lsp-progress.spin| Client %s has been removed from since it's empty",
                    client2:tostring()
                )
            end
            event.emit()
        end, Config.decay)
        logger.debug(
            "|lsp-progress.spin| Token %s is done in client %s, remove series later...",
            token,
            client:tostring()
        )
    end
    -- if client is stopped, remove this client later
    if vim.lsp.client_is_stopped(client_id) then
        vim.defer_fn(function()
            -- check client id again
            if not has_client(client_id) then
                logger.debug(
                    "|lsp-progress.spin| Client id %d not found, stop remove series",
                    client_id
                )
                event.emit()
                return
            end
            -- if this client is stopped, remove it from Clients
            remove_client(client_id)
            logger.debug(
                "|lsp-progress.spin| Client id %d has been removed from since it's stopped",
                client_id
            )
            event.emit()
        end, Config.decay)
        logger.debug(
            "|lsp-progress.spin| Client id %d is stopped, remove it later...",
            client_id
        )
    end

    -- notify user to refresh UI
    event.emit()
end

--- @param err any
--- @param msg table<string, any>
--- @param ctx table<string, any>
--- @return nil
local function progress_handler(err, msg, ctx)
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
        local series = new_series(
            value.title,
            value.message,
            value.percentage,
            Protocol.PROGRESS
        )
        client:add_series(token, series)
        -- start spin, it will also notify user at a fixed rate
        spin(client_id, token)
        logger.debug(
            "|lsp-progress.progress_handler| Add new series to client %s: %s",
            client:tostring(),
            series:tostring()
        )
    elseif value.kind == "report" then
        local series = client:get_series(token)
        if series then
            series:update(value.message, value.percentage)
            client:add_series(token, series)
            logger.debug(
                "|lsp-progress.progress_handler| Update series in client %s: %s",
                client:tostring(),
                series:tostring()
            )
        else
            logger.debug(
                "|lsp-progress.progress_handler| Series (token: %s) not found in client %s when updating",
                token,
                client:tostring()
            )
        end
    else
        if value.kind ~= "end" then
            logger.warn(
                "|lsp-progress.progress_handler| Unknown message kind `%s` from client %s",
                value.kind,
                client:tostring()
            )
        end
        if client:has_series(token) then
            local series = client:get_series(token)
            series:finish(value.message)
            client:format()
            logger.debug(
                "|lsp-progress.progress_handler| Series done in client %s: %s",
                client:tostring(),
                series:tostring()
            )
        else
            logger.debug(
                "|lsp-progress.progress_handler| Series (token: %s) not found in client %s when ending",
                token,
                client:tostring()
            )
        end
    end

    -- notify user to refresh UI
    event.emit()
end

local WindowShowMessageTypeMapping = {
    [1] = "ErrorMsg",
    [2] = "WarningMsg",
    [3] = "Comment",
    [4] = "Comment",
}

--- @param err any
--- @param msg table<string, any>
--- @param ctx table<string, any>
--- @return nil
local function window_show_message_handler(err, msg, ctx)
    local client_id = ctx.client_id
    local nvim_lsp_client = vim.lsp.get_client_by_id(client_id)
    local client_name = nvim_lsp_client and nvim_lsp_client.name or "unknown"

    -- register client id if not exist
    register_client(client_id, client_name)

    local value = msg.message
    local type = msg.type
    local client = get_client(client_id)

    -- add task
    local series =
        new_series(nil, value.message, nil, Protocol.WINDOW_SHOW_MESSAGE)
    client:add_series(WINDOW_SHOW_MESSAGE_TOKEN, series)
    -- start spin, it will also notify user at a fixed rate
    spin(client_id, type)
    logger.debug(
        "|lsp-progress.progress_handler| Add new series to client %s: %s",
        client:tostring(),
        series:tostring()
    )

    -- notify user to refresh UI
    event.emit()
end

--- @param option table<string, any>
--- @return string|nil
local function progress(option)
    option = vim.tbl_deep_extend("force", vim.deepcopy(Config), option or {})

    local active_clients_count = #vim.lsp.get_active_clients()
    if active_clients_count <= 0 then
        return ""
    end

    local client_messages = {}
    for _, client_obj in pairs(LspClients) do
        local msg = client_obj:format_result()
        if msg and msg ~= "" then
            table.insert(client_messages, msg)
            logger.debug(
                "|lsp-progress.progress| Get client %s format result: %s",
                client_obj:tostring(),
                vim.inspect(client_messages)
            )
        end
    end
    local content = option.format(client_messages)
    logger.debug(
        "|lsp-progress.progress| Progress format: %s",
        vim.inspect(content)
    )
    if option.max_size >= 0 then
        if vim.fn.strdisplaywidth(content) > option.max_size then
            content = vim.fn.strcharpart(
                content,
                0,
                vim.fn.max({ option.max_size - 1, 0 })
            ) .. "…"
        end
    end
    return content
end

--- @param option table<string, any>
--- @return nil
local function setup(option)
    -- setup config
    Config = defaults.setup(option)

    -- setup logger
    logger.setup(
        Config.debug,
        Config.console_log,
        Config.file_log,
        Config.file_log_name
    )

    -- setup event
    event.setup(Config.event, Config.event_update_time_limit)

    -- setup series
    require("lsp-progress.series").setup(Config.series_format)

    -- init client
    require("lsp-progress.client").setup(Config.client_format, Config.spinner)

    if not Registered then
        if vim.lsp.handlers[Protocol.PROGRESS] then
            local old_handler = vim.lsp.handlers[Protocol.PROGRESS]
            vim.lsp.handlers[Protocol.PROGRESS] = function(...)
                old_handler(...)
                progress_handler(...)
            end
            logger.debug(
                "|lsp-progress.setup| '$/progress' handler registered with old handler"
            )
        else
            vim.lsp.handlers[Protocol.PROGRESS] = progress_handler
            logger.debug(
                "|lsp-progress.setup| new '$/progress' handler registered"
            )
        end

        if Config.enable_window_show_message then
            if vim.lsp.handlers[Protocol.WINDOW_SHOW_MESSAGE] then
                local old_handler =
                    vim.lsp.handlers[Protocol.WINDOW_SHOW_MESSAGE]
                vim.lsp.handlers[Protocol.WINDOW_SHOW_MESSAGE] = function(...)
                    old_handler(...)
                    window_show_message_handler(...)
                end
                logger.debug(
                    "|lsp-progress.setup| 'window/showMessage' handler registered with old handler"
                )
            else
                vim.lsp.handlers[Protocol.WINDOW_SHOW_MESSAGE] =
                    window_show_message_handler
                logger.debug(
                    "|lsp-progress.setup| new 'window/showMessage' handler registered"
                )
            end
        end
        Registered = true
    end
end

--- @type table<string, function>
local M = {
    setup = setup,
    progress = progress,
}

return M