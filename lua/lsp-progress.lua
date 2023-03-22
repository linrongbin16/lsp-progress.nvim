local logger = require("lsp-progress.logger")
local defaults = require("lsp-progress.defaults")
local event = require("lsp-progress.event")
local new_series = require("lsp-progress.series").new_series
local new_client = require("lsp-progress.client").new_client

-- global variable
local Config = {}
local Registered = false
local LspClients = {}

-- {
-- Clients

local function has_client(client_id)
    return LspClients[client_id] ~= nil
end

local function get_client(client_id)
    return LspClients[client_id]
end

local function remove_client(client_id)
    LspClients[client_id] = nil
end

local function register_client(client_id, client_name)
    if not has_client(client_id) then
        LspClients[client_id] = new_client(client_id, client_name)
        logger.debug("Register client %s", get_client(client_id):tostring())
    end
end

-- }

local function spin(client_id, token)
    local function spin_again()
        spin(client_id, token)
    end

    -- check client exist
    if not has_client(client_id) then
        logger.debug("Client id %d not found, stop spin", client_id)
        return
    end

    -- check token exist
    local client = get_client(client_id)
    if not client:has_series(token) then
        logger.debug(
            "Token %s not found in client %s, stop spin",
            token,
            client:tostring()
        )
        return
    end

    client:increase_spin_index(#Config.spinner)
    vim.defer_fn(spin_again, Config.spin_update_time)

    local series = client:get_series(token)
    -- if series done, remove this series from client later
    if series.done then
        vim.defer_fn(function()
            -- check client id again
            if not has_client(client_id) then
                logger.debug(
                    "Client id %d not found, stop remove series",
                    client_id
                )
                event.emit()
                return
            end
            local client2 = get_client(client_id)
            -- check token again
            if not client2:has_series(token) then
                logger.debug(
                    "Token %s not found in client %s, stop remove series",
                    token,
                    client2:tostring()
                )
                event.emit()
                return
            end
            client2:remove_series(token)
            logger.debug(
                "Token %s has been removed from client %s since it's done",
                token,
                client2:tostring()
            )
            if client2:empty() then
                -- if client2 is empty, also remove it from Clients
                remove_client(client_id)
                logger.debug(
                    "Client %s has been removed from since it's empty",
                    client2:tostring()
                )
            end
            event.emit()
        end, Config.decay)
        logger.debug(
            "Token %s is done in client %s, remove series later...",
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
                    "Client id %d not found, stop remove series",
                    client_id
                )
                event.emit()
                return
            end
            -- if this client is stopped, remove it from Clients
            remove_client(client_id)
            logger.debug(
                "Client id %d has been removed from since it's stopped",
                client_id
            )
            event.emit()
        end, Config.decay)
        logger.debug("Client id %d is stopped, remove it later...", client_id)
    end

    -- notify user to refresh UI
    event.emit()
end

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
        local series = new_series(value.title, value.message, value.percentage)
        client:add_series(token, series)
        -- start spin, it will also notify user at a fixed rate
        spin(client_id, token)
        logger.debug(
            "Add new series to (client_id:%d, token:%s): %s",
            client_id,
            token,
            vim.inspect(series)
        )
    elseif value.kind == "report" then
        local series = client:get_series(token)
        if series then
            series:update(value.message, value.percentage)
            client:format()
            logger.debug(
                "Update series (client_id:%d, token:%s): %s",
                client_id,
                token,
                vim.inspect(series)
            )
        else
            logger.debug(
                "Series not found when updating (client_id:%d, token:%s)",
                client_id,
                token
            )
        end
    else
        if value.kind ~= "end" then
            logger.warn(
                "Unknown message kind `%s` from client %d-%s",
                value.kind,
                client_id,
                client_name
            )
        end
        if client:has_series(token) then
            local series = client:get_series(token)
            series:finish(value.message)
            client:format()
            logger.debug(
                "Series done (client_id:%d, token:%s): %s",
                client_id,
                token,
                vim.inspect(series)
            )
        else
            logger.debug(
                "Series not found when ending (client_id:%d, token:%s)",
                client_id,
                token
            )
        end
    end

    -- notify user to refresh UI
    event.emit()
end

local function progress()
    local active_clients_count = #vim.lsp.get_active_clients()
    if active_clients_count <= 0 then
        return nil
    end

    local client_messages = {}
    for _, client_obj in pairs(LspClients) do
        local msg = client_obj:format_result()
        if msg and msg ~= "" then
            table.insert(client_messages, msg)
        end
    end
    local content = Config.format(client_messages)
    if Config.max_size >= 0 then
        if vim.fn.strdisplaywidth(content) > Config.max_size then
            content = vim.fn.strcharpart(
                content,
                0,
                vim.fn.max(Config.max_size - 1, 0)
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
        if vim.lsp.handlers["$/progress"] then
            local old_handler = vim.lsp.handlers["$/progress"]
            vim.lsp.handlers["$/progress"] = function(...)
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
