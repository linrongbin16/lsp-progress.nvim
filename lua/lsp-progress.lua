local logger = require("lsp-progress.logger")
local defaults = require("lsp-progress.defaults")
local event = require("lsp-progress.event")
local new_series = require("lsp-progress.series").new_series
local new_client = require("lsp-progress.client").new_client

-- global variable
local Config = {}
local Registered = false
local LspClients = {}

-- util
local function notify()
    event.emit(Config.event, Config.event_update_time_limit)
end

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
        logger.debug(
            "Register client (client_id:%d, client_name:%s) in Clients",
            client_id,
            client_name
        )
    end
end

-- }

local function spin(client_id, token)
    local function spinAgain()
        spin(client_id, token)
    end

    if not has_client(client_id) then
        logger.debug(
            "Series not found (client_id:%d, token:%s), client id not found, stop spin",
            client_id,
            token
        )
        return
    end
    local client = get_client(client_id)
    if not client:has_series(token) then
        logger.debug(
            "Series not found (client_id:%d, token:%s), token not found, stop spin",
            client_id,
            token
        )
        return
    end
    local series = client:get_series(token)

    client:increase_spin_index(#Config.spinner)
    notify()
    -- no need to check if series is done or not, just keep spinning
    vim.defer_fn(spinAgain, Config.spin_update_time)

    -- if series done, remove this series from data in decay time
    if series.done then
        local function remove_series_later()
            if not has_client(client_id) then
                logger.debug(
                    "Series not found (client_id:%d, token:%s), client id not found, stop remove series",
                    client_id,
                    token
                )
                return
            end
            local client2 = get_client(client_id)
            if not client2:has_series(token) then
                logger.debug(
                    "Series not found (client_id:%d, token:%s), token not found, stop remove series",
                    client_id,
                    token
                )
                return
            end
            client2:remove_series(token)
            logger.debug(
                "Series removed (client_id:%d, token:%s)",
                client_id,
                token
            )
            if client2:empty() then
                -- if client is empty, also remove it from Clients
                remove_client(client_id)
            end
            notify()
        end

        vim.defer_fn(remove_series_later, Config.decay)
        logger.debug(
            "Series done (client_id:%d, token:%s), remove series later...",
            client_id,
            token
        )
    end
end

local function progress_handler(err, msg, ctx)
    local client_id = ctx.client_id
    local the_neovim_client = vim.lsp.get_client_by_id(client_id)
    local client_name = the_neovim_client and the_neovim_client.name
        or "unknown"

    -- register client id if not exist
    register_client(client_id, client_name)

    local value = msg.value
    local token = msg.token

    local client = get_client(client_id)
    if value.kind == "begin" then
        -- add task
        local series = new_series(value.title, value.message, value.percentage)
        client:add_series(token, series)
        spin(client_id, token) -- start spin, inside it will notify user
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
            notify()
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
            notify()
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
end

local function progress()
    local active_clients_count = #vim.lsp.get_active_clients()
    if active_clients_count <= 0 then
        return ""
    end

    local client_messages = {}
    for client_id, client_data in pairs(LspClients) do
        if vim.lsp.client_is_stopped(client_id) then
            -- if this client is stopped, remove it from Clients
            remove_client(client_id)
        else
            local deduped_serieses = {}
            for token, series in pairs(client_data.serieses) do
                local key = series:key()
                if deduped_serieses[key] then
                    -- if already has a message with same title+message
                    -- dedup it, choose the one has nil or lower percentage
                    -- (we guess they have more time to complete)

                    local old_series = deduped_serieses[key]
                    if series.percentage == nil then
                        deduped_serieses[key] = series
                        logger.debug(
                            "Series duplicated by key `%s` (client_id:%d, token:%s), choose new series because its percentage is nil",
                            fmtkey,
                            client_id,
                            token
                        )
                    elseif old_series.percentage ~= nil then
                        -- two series have percentage
                        deduped_serieses[key] = series.percentage
                                    < old_series.percentage
                                and series
                            or old_series
                        logger.debug(
                            "Series duplicated by key `%s` (client_id:%d, token:%s), both series has percentage, choose lower one (new: %d, old: %d)",
                            dedup_key,
                            client_id,
                            token,
                            series.percentage,
                            old_series.percentage
                        )
                    else
                        -- otherwise, series has a percentage, old_series don't has
                        -- keep old one
                        logger.debug(
                            "Series duplicated by key `%s` (client_id:%d, token:%s), keeps old series because its percentage is nil",
                            dedup_key,
                            client_id,
                            token
                        )
                    end
                else
                    deduped_serieses[key] = series
                    logger.debug(
                        "Series key `%s` (client_id:%d, token:%s) first show up, add it to deduped_serieses",
                        dedup_key,
                        client_id,
                        token
                    )
                end
            end
            local series_messages = {}
            for _, series in pairs(deduped_serieses) do
                local msg = Config.series_format(
                    series.title,
                    series.message,
                    series.percentage,
                    series.done
                )
                logger.debug(
                    "Get series msg (client_id:%d) in progress: %s",
                    client_id,
                    vim.inspect(msg)
                )
                table.insert(series_messages, msg)
            end
            local clientmsg = Config.client_format(
                client_data.client_name,
                Config.spinner[client_data.spin_index + 1],
                series_messages
            )
            if clientmsg and clientmsg ~= "" then
                table.insert(client_messages, clientmsg)
            end
        end
    end
    local content = Config.format(client_messages)
    if Config.max_size >= 0 then
        if vim.fn.strdisplaywidth(content) > Config.max_size then
            content = vim.fn.strcharpart(content, 0, Config.max_size - 1)
                .. "…"
        end
    end
    return content
end

local function setup(option)
    -- init config
    Config = defaults.setup(option)

    -- init logger
    logger.setup(
        Config.debug,
        Config.console_log,
        Config.file_log,
        Config.file_log_name
    )
    -- init event
    event.reset()

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