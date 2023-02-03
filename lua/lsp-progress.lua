-- Credit:
--  * https://github.com/nvim-lua/lsp-status.nvim
--  * https://github.com/j-hui/fidget.nvim

-- {
-- global

local DEFAULTS = {
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    spin_update_time = 200,
    sign = " LSP", -- nf-fa-gear \uf013
    seperator = " ",
    decay = 1000,
    event = "LspProgressStatusUpdated",
    event_update_time_limit = 125,
    max_size = 120,
    debug = false,
    console_log = true,
    file_log = false,
    file_log_name = "lsp-progress.log",
}
local CONFIG = {}
local REGISTERED = false
local CLIENTS = {}
local LOGGER = nil
local EMITED = false

-- }

-- {
-- util

local function resetEmited()
    EMITED = false
end

local function emitEvent()
    if not EMITED then
        EMITED = true
        vim.cmd("doautocmd User " .. CONFIG.event)
        vim.defer_fn(resetEmited, CONFIG.event_update_time_limit)
        LOGGER:debug("Emit user event:" .. CONFIG.event)
    end
end

-- {
-- LoggerCls

local LogLevel = {
    ERR = {
        VALUE = 100,
        ECHOHL = "ErrorMsg",
    },
    WARN = {
        VALUE = 90,
        ECHOHL = "WarningMsg",
    },
    INFO = {
        VALUE = 70,
        ECHOHL = "None",
    },
    DEBUG = {
        VALUE = 50,
        ECHOHL = "Comment",
    },
}

local LoggerCls = {
    level = "DEBUG",
    console = true,
    file = false,
    filename = nil,
    counter = 0,
}

function LoggerCls:log(level, msg)
    if LogLevel[level].VALUE < LogLevel[self.level].VALUE then
        return
    end
    local traceinfo = debug.getinfo(2, "Sl")
    local lineinfo = traceinfo.short_src .. ":" .. traceinfo.currentline
    local split_msg = vim.split(msg, "\n")

    local function log_format(c, s)
        return string.format(
            "[lsp-progress] %s-%d %s (%s): %s",
            os.date("%Y-%m-%d %H:%M:%S"),
            c,
            self.level,
            lineinfo,
            s
        )
    end

    if self.console then
        vim.cmd("echohl " .. LogLevel[self.level].ECHOHL)
        for _, m in ipairs(split_msg) do
            vim.cmd(string.format([[echom "%s"]], vim.fn.escape(log_format(self.counter, m), '"')))
        end
        vim.cmd("echohl " .. LogLevel.INFO.ECHOHL)
    end
    if self.file then
        local fp = io.open(self.filename, "a")
        for _, m in ipairs(split_msg) do
            fp:write(log_format(self.counter, m) .. "\n")
        end
        fp:close()
    end
    self.counter = self.counter + 1
end

function LoggerCls:err(msg)
    self:log("ERR", msg)
end

function LoggerCls:warn(msg)
    self:log("WARN", msg)
end

function LoggerCls:info(msg)
    self:log("INFO", msg)
end

function LoggerCls:debug(msg)
    self:log("DEBUG", msg)
end

local function new_logger(option)
    local logger = vim.tbl_extend("force", vim.deepcopy(LoggerCls), option or {})
    return logger
end

-- }

-- }

-- {
-- data class

-- {
-- SeriesCls

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

function SeriesCls:format()
    local builder = {}
    local has_title = false
    local has_message = false
    if self.title and self.title ~= "" then
        table.insert(builder, self.title)
        has_title = true
    end
    if self.message and self.message ~= "" then
        table.insert(builder, self.message)
        has_message = true
    end
    if self.percentage then
        if has_title or has_message then
            table.insert(builder, string.format("(%.0f%%%%)", self.percentage))
        end
    end
    if self.done then
        if has_title or has_message then
            table.insert(builder, "- done")
        end
    end
    return table.concat(builder, " ")
end

function SeriesCls:formatKey()
    return tostring(self.title) .. "-" .. tostring(self.message)
end

function SeriesCls:toString()
    return "title:"
        .. tostring(self.title)
        .. ", message:"
        .. tostring(self.message)
        .. ", percentage:"
        .. tostring(self.percentage)
        .. ", done:"
        .. tostring(self.done)
end

local function new_series(title, message, percentage)
    local series = vim.tbl_extend(
        "force",
        vim.deepcopy(SeriesCls),
        { title = title, message = message, percentage = percentage, done = false }
    )
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

function ClientCls:hasSeries(token)
    return self.serieses[token] ~= nil
end

function ClientCls:removeSeries(token)
    self.serieses[token] = nil
end

function ClientCls:getSeries(token)
    return self.serieses[token]
end

function ClientCls:addSeries(token, series)
    self.serieses[token] = series
end

function ClientCls:empty()
    return next(self.serieses)
end

function ClientCls:increaseSpinIndex()
    local old = self.spin_index
    self.spin_index = (self.spin_index + 1) % #CONFIG.spinner
    LOGGER:debug("Client spin index:" .. old .. " => " .. self.spin_index)
end

local function new_client(client_id, client_name)
    local data = vim.tbl_extend("force", vim.deepcopy(ClientCls), { client_id = client_id, client_name = client_name })
    return data
end

-- }

-- {
-- CLIENTS

local ClientMapCls = {
    keep_cls = nil,
}

function ClientMapCls:hasClient(client_id)
    return self[client_id] ~= nil
end

function ClientMapCls:getClient(client_id)
    return self[client_id]
end

function ClientMapCls:removeClient(client_id)
    self[client_id] = nil
end

function ClientMapCls:registerClient(client_id, client_name)
    if not self:hasClient(client_id) then
        self[client_id] = new_client(client_id, client_name)
        LOGGER:debug(
            "Register client (client_id:" .. client_id .. ", client_name:" .. client_name .. ") in ClientMapCls"
        )
    end
end

local function new_client_map()
    local client_map = vim.tbl_extend("force", vim.deepcopy(ClientMapCls), {})
    return client_map
end

-- }

-- }

local function spin(client_id, token)
    local function spinAgain()
        spin(client_id, token)
    end

    if not CLIENTS:hasClient(client_id) then
        LOGGER:debug("Series not found: client_id:" .. client_id .. " not exist (token:" .. token .. "), stop spin")
        return
    end
    local client = CLIENTS:getClient(client_id)
    if not client:hasSeries(token) then
        LOGGER:debug(
            "Series not found: token:" .. token .. " not exist in CLIENTS[" .. client_id .. "].serieses, stop spin"
        )
        return
    end
    local series = client:getSeries(token)

    client:increaseSpinIndex() -- client increase spin_index
    emitEvent() -- notify user to update spinning animation
    vim.defer_fn(spinAgain, CONFIG.spin_update_time) -- no need to check if series is done or not, just keep spinning

    -- if series done, remove this series from data in decay time
    if series.done then
        local function remove_series_later()
            if not CLIENTS:hasClient(client_id) then
                LOGGER:debug(
                    "Series not found: client_id:"
                    .. client_id
                    .. " not exist (token:"
                    .. token
                    .. "), stop remove series"
                )
                return
            end
            local client2 = CLIENTS:getClient(client_id)
            if not client2:hasSeries(token) then
                LOGGER:debug(
                    "Series not found: token:"
                    .. token
                    .. " not exist in CLIENTS["
                    .. client_id
                    .. "].serieses, stop remove series"
                )
                return
            end
            client2:removeSeries(token)
            LOGGER:debug("Series removed (client_id:" .. client_id .. ",token:" .. token .. ")")
            if client2:empty() then
                -- if client is empty, also remove it from CLIENTS
                CLIENTS:removeClient(client_id)
            end
            emitEvent() -- notify user
        end

        vim.defer_fn(remove_series_later, CONFIG.decay)
        LOGGER:debug("Series done (client_id:" .. client_id .. ",token:" .. token .. "), remove series later...")
    end
end

local function progress_handler(err, msg, ctx)
    local client_id = ctx.client_id
    local the_neovim_client = vim.lsp.get_client_by_id(client_id)
    local client_name = the_neovim_client and the_neovim_client.name or "unknown"

    -- register client id if not exist
    CLIENTS:registerClient(client_id, client_name)

    local value = msg.value
    local token = msg.token

    local client = CLIENTS:getClient(client_id)
    if value.kind == "begin" then
        -- add task
        local series = new_series(value.title, value.message, value.percentage)
        client:addSeries(token, series)
        spin(client_id, token) -- start spin, inside it will notify user
        LOGGER:debug("Add new series to (client_id:" .. client_id .. ", token:" .. token .. "): " .. series:toString())
    elseif value.kind == "report" then
        local series = client:getSeries(token)
        if series then
            series:update(value.message, value.percentage)
            emitEvent() -- notify user
            LOGGER:debug("Update series (client_id:" .. client_id .. ", token:" .. token .. "): " .. series:toString())
        else
            LOGGER:debug("Series not found when update: client_id:" .. client_id .. ", token:" .. token)
        end
    else
        local function client_format()
            return "from client:[" .. client_id .. "-" .. client_name .. "]!"
        end

        if value.kind ~= "end" then
            LOGGER:warn("Unknown message kind `" .. value.kind .. "` " .. client_format())
        end
        if client:hasSeries(token) then
            local series = client:getSeries(token)
            series:finish(value.message)
            emitEvent() -- notify user
            LOGGER:debug("Series done (client_id:" .. client_id .. ", token:" .. token .. "): " .. series:toString())
        else
            LOGGER:debug("Series not found when end: client_id:" .. client_id .. ", token:" .. token)
        end
    end
end

local function progress()
    local active_clients_count = #vim.lsp.get_active_clients()
    if active_clients_count <= 0 then
        return ""
    end

    local messages = {}
    for client_id, client_data in pairs(CLIENTS) do
        if vim.lsp.client_is_stopped(client_id) then
            -- if this client is stopped, remove it from CLIENTS
            CLIENTS:removeClient(client_id)
        else
            local deduped_serieses = {}
            for token, series in pairs(client_data.serieses) do
                local key = series:formatKey()
                if deduped_serieses[key] then
                    -- if already has a message with same title+message
                    -- dedup it, choose the one has nil or lower percentage
                    -- (we guess they have more time to complete)

                    local old_series = deduped_serieses[key]
                    if series.percentage == nil then
                        deduped_serieses[key] = series
                        LOGGER:debug(
                            "Series duplicated by formatKey `"
                            .. key
                            .. "` (client_id:"
                            .. client_id
                            .. ", token:"
                            .. token
                            .. "), choose new series for its percentage is nil"
                        )
                    elseif old_series.percentage ~= nil then
                        -- two series have percentage
                        deduped_serieses[key] = series and series.percentage < old_series.percentage or old_series
                        LOGGER:debug(
                            "Series duplicated by formatKey `"
                            .. key
                            .. "` (client_id:"
                            .. client_id
                            .. ", token:"
                            .. token
                            .. "), both series has percentage, choose lower one ("
                            .. series.percentage
                            .. ":"
                            .. old_series.percentage
                            .. ")"
                        )
                    else
                        -- otherwise, series has a percentage, old_series don't has
                        -- keep old one
                        LOGGER:debug(
                            "Series duplicated by formatKey `"
                            .. key
                            .. "` (client_id:"
                            .. client_id
                            .. ", token:"
                            .. token
                            .. "), keeps old series for its percentage is nil"
                        )
                    end
                else
                    deduped_serieses[key] = series
                    LOGGER:debug(
                        "Series formatKey `"
                        .. key
                        .. "` (client_id:"
                        .. client_id
                        .. ", token:"
                        .. token
                        .. ") first show up, add it to deduped_serieses"
                    )
                end
            end
            local client_messages = {}
            for _, series in pairs(deduped_serieses) do
                local msg = series:format()
                LOGGER:debug("Get series msg (client_id:" .. client_id .. ") in progress: " .. msg)
                table.insert(client_messages, msg)
            end
            if #client_messages > 0 then
                table.insert(
                    messages,
                    "["
                    .. client_data.client_name
                    .. "] "
                    .. CONFIG.spinner[client_data.spin_index + 1]
                    .. " "
                    .. table.concat(client_messages, ", ")
                )
            end
        end
    end
    if #messages > 0 then
        local content = table.concat(messages, CONFIG.seperator)
        if vim.fn.strdisplaywidth(content) > CONFIG.max_size then
            content = vim.fn.strcharpart(content, 0, CONFIG.max_size - 1) .. "…"
        end
        LOGGER:debug("Progress messages(" .. #messages .. "):" .. content)
        return CONFIG.sign .. " " .. content
    else
        LOGGER:debug("Progress messages(" .. #messages .. "): no message")
        return CONFIG.sign
    end
end

local function setup(option)
    -- override default config
    CONFIG = vim.tbl_deep_extend("force", DEFAULTS, option or {})
    LOGGER = new_logger({
        level = CONFIG.debug and "DEBUG" or "WARN",
        console = CONFIG.console_log,
        file = CONFIG.file_log,
        filename = string.format("%s/%s", vim.fn.stdpath("data"), CONFIG.file_log_name),
    })
    CLIENTS = new_client_map()

    if not REGISTERED then
        if vim.lsp.handlers["$/progress"] then
            local old_handler = vim.lsp.handlers["$/progress"]
            vim.lsp.handlers["$/progress"] = function(...)
                old_handler(...)
                progress_handler(...)
            end
        else
            vim.lsp.handlers["$/progress"] = progress_handler
        end
        REGISTERED = true
    end
end

local M = {
    setup = setup,
    progress = progress,
}

return M
