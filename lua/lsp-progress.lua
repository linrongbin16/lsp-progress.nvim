local logger = require("lsp-progress.logger")
local defaults = require("lsp-progress.defaults")
local event = require("lsp-progress.event")
local Series = require("lsp-progress.series").Series
local Client = require("lsp-progress.client").Client

local NVIM_VERSION_010 = vim.fn.has("nvim-0.10") > 0

-- global variable

local Registered = false

--- @type lsp_progress.Configs
local Configs = {}

-- client manager {

--- @type table<lsp_progress.ClientId, lsp_progress.Client>
local LspClients = {}

--- @package
--- @param client_id lsp_progress.ClientId
--- @return boolean
local function _has_client(client_id)
    return LspClients[client_id] ~= nil
end

--- @package
--- @param client_id lsp_progress.ClientId
--- @return lsp_progress.Client
local function _get_client(client_id)
    return LspClients[client_id]
end

--- @package
--- @param client_id lsp_progress.ClientId
local function _remove_client(client_id)
    LspClients[client_id] = nil
    if not next(LspClients) then
        LspClients = {}
    end
end

--- @package
--- @param client_id lsp_progress.ClientId
--- @param client_name string
local function _register_client(client_id, client_name)
    if not _has_client(client_id) then
        LspClients[client_id] = Client:new(client_id, client_name)
        -- logger.debug(
        --     "|lsp-progress.register_client| Register client %s",
        --     vim.inspect(_get_client(client_id))
        -- )
    end
end

-- client manager }

--- @param client_id lsp_progress.ClientId
--- @param token lsp_progress.SeriesToken
local function spin(client_id, token)
    local function spin_again()
        spin(client_id, token)
    end

    -- check client exist
    if not _has_client(client_id) then
        -- logger.debug(
        --     "|lsp-progress.spin| Client id %d not found, stop spin",
        --     client_id
        -- )
        return
    end

    -- check token exist
    local cli = _get_client(client_id)
    if not cli:has_series(token) then
        -- logger.debug(
        --     "|lsp-progress.spin| Token %s not found in client %s, stop spin",
        --     token,
        --     vim.inspect(cli)
        -- )
        return
    end

    cli:increase_spin_index()
    vim.defer_fn(spin_again, Configs.spin_update_time)

    local ss = cli:get_series(token)
    -- if series done, remove this series from client later
    if ss.done then
        vim.defer_fn(function()
            -- check client id again
            if not _has_client(client_id) then
                -- logger.debug(
                --     "|lsp-progress.spin| Client id %d not found, stop remove series",
                --     client_id
                -- )
                event.emit()
                return
            end
            local cli2 = _get_client(client_id)
            -- check token again
            if not cli2:has_series(token) then
                -- logger.debug(
                --     "|lsp-progress.spin| Token %s not found in client %s, stop remove series",
                --     token,
                --     vim.inspect(cli2)
                -- )
                event.emit()
                return
            end
            cli2:remove_series(token)
            -- logger.debug(
            --     "|lsp-progress.spin| Token %s has been removed from client %s since it's done",
            --     token,
            --     vim.inspect(cli2)
            -- )
            if cli2:empty() then
                -- if client2 is empty, also remove it from Clients
                _remove_client(client_id)
                -- logger.debug(
                --     "|lsp-progress.spin| Client %s has been removed from since it's empty",
                --     vim.inspect(cli2)
                -- )
            end
            event.emit()
        end, Configs.decay)
        -- logger.debug(
        --     "|lsp-progress.spin| Token %s is done in client %s, remove series later...",
        --     token,
        --     vim.inspect(cli)
        -- )
    end
    -- if client is stopped, remove this client later
    if vim.lsp.client_is_stopped(client_id) then
        vim.defer_fn(function()
            -- check client id again
            if not _has_client(client_id) then
                -- logger.debug(
                --     "|lsp-progress.spin| Client id %d not found, stop remove series",
                --     client_id
                -- )
                event.emit()
                return
            end
            -- if this client is stopped, remove it from Clients
            _remove_client(client_id)
            -- logger.debug(
            --     "|lsp-progress.spin| Client id %d has been removed from since it's stopped",
            --     client_id
            -- )
            event.emit()
        end, Configs.decay)
        -- logger.debug(
        --     "|lsp-progress.spin| Client id %d is stopped, remove it later...",
        --     client_id
        -- )
    end

    -- notify user to refresh UI
    event.emit()
end

--- @alias lsp_progress.LspClientObj {id:lsp_progress.ClientId,name:string}
--- @alias lsp_progress.LspProgressObj {token:lsp_progress.SeriesToken,value:{kind:"begin"|"report"|"end",title:string?,message:string?,percentage:integer?}}
--- @param client lsp_progress.LspClientObj
--- @param progress lsp_progress.LspProgressObj
local function update_progress(client, progress)
    local client_id = client.id
    local client_name = client.name

    -- register client id if not exist
    _register_client(client_id, client_name)

    local token = progress.token
    local value = progress.value

    local cli = _get_client(client_id)
    if value.kind == "begin" then
        -- add task
        local ss = Series:new(value.title, value.message, value.percentage)
        cli:add_series(token, ss)
        -- start spin, it will also notify user at a fixed rate
        spin(client_id, token)
        -- logger.debug(
        --     "|progress_handler| add new series to client(%s): %s",
        --     vim.inspect(cli),
        --     vim.inspect(ss)
        -- )
    elseif value.kind == "report" then
        local ss = cli:get_series(token)
        if ss then
            ss:update(value.message, value.percentage)
            cli:add_series(token, ss)
            -- logger.debug(
            --     "|progress_handler| update series in client(%s): %s",
            --     vim.inspect(cli),
            --     vim.inspect(ss)
            -- )
            -- else
            -- logger.debug(
            --     "|lsp-progress.progress_handler| Series (token: %s) not found in client %s when updating",
            --     token,
            --     vim.inspect(cli)
            -- )
        end
    else
        if value.kind ~= "end" then
            logger.warn(
                "|lsp-progress.progress_handler| Unknown message kind `%s` from client %s",
                value.kind,
                vim.inspect(cli)
            )
        end
        if cli:has_series(token) then
            local ss = cli:get_series(token)
            ss:finish(value.message)
            cli:format()
            -- logger.debug(
            --     "|progress_handler| series is done in client(%s): %s",
            --     vim.inspect(cli),
            --     vim.inspect(ss)
            -- )
            -- else
            -- logger.debug(
            --     "|lsp-progress.progress_handler| Series (token: %s) not found in client %s when ending",
            --     token,
            --     vim.inspect(cli)
            -- )
        end
    end

    -- notify user to refresh UI
    event.emit()
end

--- @param err string?
--- @param msg table<string, any>
--- @param ctx table<string, any>
local function method_handler(err, msg, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id) --[[@as table]]
    update_progress(client, msg)
end

local function _is_lsp_client_obj(c)
    return type(c) == "table" and c.id and type(c.name) == "string"
end

local function _is_lsp_progress_obj(p)
    return type(p) == "table" and p.token and type(p.value) == "table"
end

local function event_handler()
    local lsp_clients = vim.lsp.get_active_clients()
    for _, client in ipairs(lsp_clients) do
        if _is_lsp_client_obj(client) and type(client.progress) == "table" then
            for progress in client.progress do
                -- logger.debug("|setup| v0.10 progress:%s", vim.inspect(progress))
                if _is_lsp_progress_obj(progress) then
                    update_progress(client, progress)
                end
            end
        end
    end
end

--- @param option lsp_progress.Configs?
--- @return string?
local function progress(option)
    option = vim.tbl_deep_extend("force", vim.deepcopy(Configs), option or {})

    local active_clients_count = #vim.lsp.get_active_clients()
    if active_clients_count <= 0 then
        return ""
    end

    local client_messages = {}
    for _, cli in pairs(LspClients) do
        local msg = cli:format_result()
        if msg and msg ~= "" then
            table.insert(client_messages, msg)
            -- logger.debug(
            --     "|lsp-progress.progress| Get client %s format result: %s",
            --     vim.inspect(cli),
            --     vim.inspect(client_messages)
            -- )
        end
    end
    local ok, result = pcall(option.format, client_messages)
    if not ok then
        logger.throw(
            "failed to invoke 'format' function! error: %s, params: %s",
            vim.inspect(result),
            vim.inspect(client_messages)
        )
    end
    local content = result
    if option.max_size >= 0 then
        if vim.fn.strdisplaywidth(content) > option.max_size then
            content = vim.fn.strpart(
                content,
                0,
                math.max(option.max_size - 1, 0)
            ) .. "…"
        end
    end
    if type(content) == "string" then
        content = content:gsub("%%", "%%%%")
    end

    logger.debug(
        "|lsp-progress.progress| returned content: %s",
        vim.inspect(content)
    )
    return content
end

--- @param option lsp_progress.Configs
local function setup(option)
    -- setup config
    Configs = defaults.setup(option)

    -- setup logger
    logger.setup(
        Configs.debug and "DEBUG" or "INFO",
        Configs.console_log,
        Configs.file_log,
        Configs.file_log_name
    )

    -- setup event
    event.setup(
        Configs.event,
        Configs.event_update_time_limit,
        Configs.regular_internal_update_time,
        Configs.disable_events_opts
    )

    -- setup series
    require("lsp-progress.series").setup(Configs.series_format)

    -- init client
    require("lsp-progress.client").setup(Configs.client_format, Configs.spinner)

    if NVIM_VERSION_010 then
        -- see:
        -- https://github.com/neovim/neovim/blob/582d7f47905d82f315dc852a9d2937cd5b655e55/runtime/doc/news.txt#L44
        -- https://github.com/neovim/neovim/blob/582d7f47905d82f315dc852a9d2937cd5b655e55/runtime/lua/vim/lsp/util.lua#L348
        vim.api.nvim_create_autocmd("LspProgress", { callback = event_handler })
    else
        if not Registered then
            if vim.lsp.handlers["$/progress"] then
                local old_handler = vim.lsp.handlers["$/progress"]
                vim.lsp.handlers["$/progress"] = function(...)
                    old_handler(...)
                    method_handler(...)
                end
            else
                vim.lsp.handlers["$/progress"] = method_handler
            end
            Registered = true
        end
    end
end

local M = {
    setup = setup,
    progress = progress,
    _has_client = _has_client,
    _get_client = _get_client,
    _remove_client = _remove_client,
    _register_client = _register_client,
}

return M
