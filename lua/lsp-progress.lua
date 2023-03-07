local logger = require("lsp-progress.logger")

-- {
-- global variable

local Defaults = {
    --- Spinning icon array.
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    --- Spinning update time in milliseconds.
    spin_update_time = 200,
    --- Last message is cached in decay time in milliseconds.
    -- Messages could be really fast, appear and disappear in an instant, so
    -- here cache the last message for a while for user view.
    decay = 1000,
    --- User event name.
    event = "LspProgressStatusUpdated",
    --- Event update time limit in milliseconds.
    -- Sometimes progress handler could emit many events in an instant, while
    -- refreshing statusline cause too heavy synchronized IO, so limit the
    -- event emit rate to reduce the cost.
    event_update_time_limit = 125,
    --- Max progress string length, by default -1 is unlimit.
    max_size = -1,
    --- Format series message.
    -- @param title      Lsp progress message title.
    -- @param message    Lsp progress message body.
    -- @param percentage Lsp progress in [0%-100%].
    -- @param done       Indicate if this message is the last one in progress.
    -- @return           A nil|string|table value. The returned value will be
    --                   passed to `client_format` as one of the
    --                   `series_messages` array, or ignored if return nil.
    series_format = function(title, message, percentage, done)
        local builder = {}
        local has_title = false
        local has_message = false
        if title and title ~= "" then
            table.insert(builder, title)
            has_title = true
        end
        if message and message ~= "" then
            table.insert(builder, message)
            has_message = true
        end
        if percentage and (has_title or has_message) then
            table.insert(builder, string.format("(%.0f%%%%)", percentage))
        end
        if done and (has_title or has_message) then
            table.insert(builder, "- done")
        end
        return table.concat(builder, " ")
    end,
    --- Format client message.
    -- @param client_name     Lsp client name.
    -- @param spinner         Lsp spinner icon.
    -- @param series_messages Formatted series message array.
    -- @return                A nil|string|table value. The returned value will
    --                        be passed to `format` as one of the
    --                        `client_messages` array, or ignored if return nil.
    client_format = function(client_name, spinner, series_messages)
        return #series_messages > 0
                and ("[" .. client_name .. "] " .. spinner .. " " .. table.concat(
                    series_messages,
                    ", "
                ))
            or nil
    end,
    --- Format (final) message.
    -- @param client_messages Formatted client message array.
    -- @return                A nil|string|table value. The returned value will be
    --                        returned from `progress` API.
    format = function(client_messages)
        local sign = " LSP" -- nf-fa-gear \uf013
        return #client_messages > 0
                and (sign .. " " .. table.concat(client_messages, " "))
            or sign
    end,
    --- Enable debug.
    debug = false,
    --- Print log to console.
    console_log = true,
    --- Print log to file.
    file_log = false,
    -- Log file to write, work with `file_log=true`.
    -- For Windows: `$env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log`.
    -- For *NIX: `~/.local/share/nvim/lsp-progress.log`.
    file_log_name = "lsp-progress.log",
}
local Config = {}
local Registered = false
local LspClients = {}
local EventEmit = false

-- }

-- {
-- user event

local function reset_event()
    EventEmit = false
end

local function emit_event()
    if not EventEmit then
        EventEmit = true
        vim.cmd("doautocmd User " .. Config.event)
        vim.defer_fn(reset_event, Config.event_update_time_limit)
        logger.debug("Emit user event:%s", Config.event)
    end
end

-- }

-- {
-- Series

local SeriesCls = {
    title = nil,
    message = nil,
    percentage = nil,
    done = false,
}

function SeriesCls:update(message, percentage)
    self.message = message
    self.percentage = percentage
end

function SeriesCls:finish(message)
    self.message = message
    self.percentage = 100
    self.done = true
end

function SeriesCls:format_key()
    return tostring(self.title) .. "-" .. tostring(self.message)
end

local function new_series(title, message, percentage)
    local series = vim.tbl_extend("force", vim.deepcopy(SeriesCls), {
        title = title,
        message = message,
        percentage = percentage,
        done = false,
    })
    return series
end

-- }

-- {
-- ClientCls

local ClientCls = {
    client_id = nil,
    client_name = nil,
    spin_index = 0,
    serieses = {},
}

function ClientCls:has_series(token)
    return self.serieses[token] ~= nil
end

function ClientCls:remove_series(token)
    self.serieses[token] = nil
end

function ClientCls:get_series(token)
    return self.serieses[token]
end

function ClientCls:add_series(token, series)
    self.serieses[token] = series
end

function ClientCls:empty()
    return next(self.serieses)
end

function ClientCls:increase_spin_index()
    local old = self.spin_index
    self.spin_index = (self.spin_index + 1) % #Config.spinner
    logger.debug("Client spin index:%d => %d", old, self.spin_index)
end

local function new_client(client_id, client_name)
    local data = vim.tbl_extend(
        "force",
        vim.deepcopy(ClientCls),
        { client_id = client_id, client_name = client_name }
    )
    return data
end

-- }

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
        -- logger.debug(
        --     "Series not found (client_id:%d, token:%s), client id not found, stop spin",
        --     client_id,
        --     token
        -- )
        return
    end
    local client = get_client(client_id)
    if not client:has_series(token) then
        -- logger.debug(
        --     "Series not found (client_id:%d, token:%s), token not found, stop spin",
        --     client_id,
        --     token
        -- )
        return
    end
    local series = client:get_series(token)

    client:increase_spin_index() -- client increase spin_index
    emit_event() -- notify user to update spinning animation
    vim.defer_fn(spinAgain, Config.spin_update_time) -- no need to check if series is done or not, just keep spinning

    -- if series done, remove this series from data in decay time
    if series.done then
        local function remove_series_later()
            if not has_client(client_id) then
                -- logger.debug(
                --     "Series not found (client_id:%d, token:%s), client id not found, stop remove series",
                --     client_id,
                --     token
                -- )
                return
            end
            local client2 = get_client(client_id)
            if not client2:has_series(token) then
                -- logger.debug(
                --     "Series not found (client_id:%d, token:%s), token not found, stop remove series",
                --     client_id,
                --     token
                -- )
                return
            end
            client2:remove_series(token)
            -- logger.debug(
            --     "Series removed (client_id:%d, token:%s)",
            --     client_id,
            --     token
            -- )
            if client2:empty() then
                -- if client is empty, also remove it from Clients
                remove_client(client_id)
            end
            emit_event() -- notify user
        end

        vim.defer_fn(remove_series_later, Config.decay)
        -- logger.debug(
        --     "Series done (client_id:%d, token:%s), remove series later...",
        --     client_id,
        --     token
        -- )
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
            emit_event() -- notify user
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
            emit_event() -- notify user
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
                local dedup_key = series:format_key()
                if deduped_serieses[dedup_key] then
                    -- if already has a message with same title+message
                    -- dedup it, choose the one has nil or lower percentage
                    -- (we guess they have more time to complete)

                    local old_series = deduped_serieses[dedup_key]
                    if series.percentage == nil then
                        deduped_serieses[dedup_key] = series
                        -- logger.debug(
                        --     "Series duplicated by format_key `%s` (client_id:%d, token:%s), choose new series because its percentage is nil",
                        --     fmtkey,
                        --     client_id,
                        --     token
                        -- )
                    elseif old_series.percentage ~= nil then
                        -- two series have percentage
                        deduped_serieses[dedup_key] = series.percentage
                                    < old_series.percentage
                                and series
                            or old_series
                        -- logger.debug(
                        --     "Series duplicated by format_key `%s` (client_id:%d, token:%s), both series has percentage, choose lower one (new: %d, old: %d)",
                        --     dedup_key,
                        --     client_id,
                        --     token,
                        --     series.percentage,
                        --     old_series.percentage
                        -- )
                    else
                        -- otherwise, series has a percentage, old_series don't has
                        -- keep old one
                        -- logger.debug(
                        --     "Series duplicated by format_key `%s` (client_id:%d, token:%s), keeps old series because its percentage is nil",
                        --     dedup_key,
                        --     client_id,
                        --     token
                        -- )
                    end
                else
                    deduped_serieses[dedup_key] = series
                    -- logger.debug(
                    --     "Series format_key `%s` (client_id:%d, token:%s) first show up, add it to deduped_serieses",
                    --     dedup_key,
                    --     client_id,
                    --     token
                    -- )
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
    Config = vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})

    -- init logger
    logger.setup(
        Config.debug,
        Config.console_log,
        Config.file_log,
        Config.file_log_name
    )
    -- init event
    reset_event()

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
