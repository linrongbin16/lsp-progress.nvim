-- Credit:
--  * https://github.com/nvim-lua/lsp-status.nvim
--  * https://github.com/j-hui/fidget.nvim

local defaults = {
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    update_time = 200,
    sign = " LSP", -- nf-fa-gear \uf013
    seperator = " ",
    decay = 1000,
    event = "LspProgressStatusUpdated",
    debug = false,
    console_log = true,
    file_log = false,
    file_log_name = "lsp-progress.log",
}
local config = {}
local state = {
    registered = false,
    clients = {}, -- client_id => data { name, tasks }
    log_level = nil,
    log_file = nil,
}

-- {
-- util

local log_level = {
    err = {
        value = 100,
        echohl = "ErrorMsg",
    },
    warn = {
        value = 90,
        echohl = "WarningMsg",
    },
    info = {
        value = 70,
        echohl = "None",
    },
    debug = {
        value = 50,
        echohl = "Comment",
    },
}

local function log_init()
    if config.debug then
        state.log_level = log_level.debug.value
    else
        state.log_level = log_level.warn.value
    end
    if config.file_log then
        state.log_file = string.format("%s/%s", vim.fn.stdpath("data"), config.file_log_name)
    end
end

local function log_log(level, msg)
    if log_level[level].value < state.log_level then
        return
    end
    local content = string.format("[lsp-progress.nvim] %s %s: %s", level, os.date("%Y-%m-%d %H:%M:%S"), msg)
    local split_content = vim.split(content, "\n")
    if config.console_log then
        vim.cmd("echohl " .. log_level[level].echohl)
        for _, c in ipairs(split_content) do
            local tmp = string.format([[echom "%s"]], vim.fn.escape(c, '"'))
            print(tmp)
            vim.cmd(tmp)
        end
        vim.cmd("echohl " .. log_level.info.echohl)
    end
    if config.file_log then
        local fp = io.open(state.log_file, "a")
        for _, c in ipairs(split_content) do
            fp:write(c .. "\n")
        end
        fp:close()
    end
end

local function log_warn(msg)
    log_log("warn", msg)
end

local function log_debug(msg)
    log_log("debug", msg)
end

local function emit_event()
    vim.cmd("doautocmd User " .. config.event)
    log_debug("Emit user event:" .. config.event)
end

-- }

-- {
-- task

local function task_new(title, message, percentage)
    return { title = title, message = message, percentage = percentage, index = 0, done = false }
end

local function task_spin(task)
    local old = task.index
    task.index = (task.index + 1) % #config.spinner
    log_debug("task spin:" .. old .. " => " .. task.index)
end

local function task_update(task, message, percentage)
    task.message = message
    task.percentage = percentage
end

local function task_done(task, message)
    task.message = message
    task.percentage = 100
    task.done = true
end

local function task_format(task, name)
    local builder = { "[" .. name .. "]" }
    local has_title = false
    local has_message = false
    if task.index then
        table.insert(builder, config.spinner[task.index + 1])
    end
    if task.title and task.title ~= "" then
        table.insert(builder, task.title)
        has_title = true
    end
    if task.message and task.message ~= "" then
        table.insert(builder, task.message)
        has_message = true
    end
    if task.percentage then
        if has_title or has_message then
            table.insert(builder, string.format("(%.0f%%%%)", task.percentage))
        end
    end
    if task.done then
        if has_title or has_message then
            table.insert(builder, "- done")
        end
    end
    return table.concat(builder, " ")
end

local function task_tostring(task)
    return "title:"
        .. tostring(task.title)
        .. ", message:"
        .. tostring(task.message)
        .. ", percentage:"
        .. tostring(task.percentage)
        .. ", index:"
        .. tostring(task.index)
        .. ", done:"
        .. tostring(task.done)
end

-- }

-- {
-- data
-- data.tasks: token => task { title, message, percentage, index, done }

local function data_new(name)
    return { name = name, tasks = {} }
end

-- }

local function spin(client_id, token)
    local function spin_again()
        spin(client_id, token)
    end

    if not state.clients[client_id] then
        log_debug(
            "task not found (client_id:"
                .. client_id
                .. " not exist in state.clients, token:"
                .. token
                .. "), stop spin"
        )
        return
    end
    local data = state.clients[client_id]
    if not data.tasks[token] then
        log_debug(
            "task not found (token:"
                .. token
                .. " not exist in state.clients[client_id:"
                .. client_id
                .. "].tasks), stop spin"
        )
        return
    end
    local task = data.tasks[token]

    task_spin(task)
    emit_event() -- notify user
    vim.defer_fn(spin_again, config.update_time) -- no need to check if task is done or not, just keep spinning

    -- if task done, remove this task from data in decay time
    if task.done then
        local function remove_task_defer()
            if not state.clients[client_id] then
                log_debug(
                    "task not found (client_id:"
                        .. client_id
                        .. " not exist in state.clients, token:"
                        .. token
                        .. "), stop remove task"
                )
                return
            end
            if not state.clients[client_id].tasks[token] then
                log_debug(
                    "task not found (token:"
                        .. token
                        .. " not exist in state.clients[client_id:"
                        .. client_id
                        .. "].tasks), stop remove task"
                )
                return
            end
            state.clients[client_id].tasks[token] = nil
            log_debug("task removed (client_id:" .. client_id .. ",token:" .. token .. ")")
            emit_event() -- notify user
        end

        vim.defer_fn(remove_task_defer, config.decay)
        log_debug("task done (client_id:" .. client_id .. ",token:" .. token .. "), defer remove task...")
    end
end

local function progress_handler(err, msg, ctx)
    local client_id = ctx.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    local client_name
    if client then
        client_name = client.name
    else
        client_name = "unknown"
    end

    -- register client id if not exist
    if not state.clients[client_id] then
        state.clients[client_id] = data_new(client_name)
        log_debug("register client_id:" .. client_id .. ", client_name:" .. client_name .. " in state.clients")
    end

    local value = msg.value
    local token = msg.token

    if not value.kind then
        return
    end

    local tasks = state.clients[client_id].tasks
    if value.kind == "begin" then
        -- add task
        tasks[token] = task_new(value.title, value.message, value.percentage)
        log_debug(
            "add task in state.clients[client_id:"
                .. client_id
                .. "].tasks[token:"
                .. token
                .. "]: "
                .. task_tostring(tasks[token])
        )
        -- start spin, inside it will notify user
        spin(client_id, token)
    elseif value.kind == "report" then
        task_update(tasks[token], value.message, value.percentage)
        emit_event() -- notify user
        log_debug(
            "update task in state.clients[client_id:"
                .. client_id
                .. "].tasks[token:"
                .. token
                .. "]: "
                .. task_tostring(tasks[token])
        )
    else
        local function from_client_msg()
            return "from client:[" .. client_id .. "-" .. client_name .. "]!"
        end

        if value.kind ~= "end" then
            log_warn("Unknown message `" .. value.kind .. "` " .. from_client_msg())
        end
        if tasks[token] == nil then
            log_warn("Received `end` message with no corressponding `begin` " .. from_client_msg())
        else
            task_done(tasks[token], value.message)
            emit_event() -- notify user
            log_debug(
                "done task in state.clients[client_id:"
                    .. client_id
                    .. "].tasks[token:"
                    .. token
                    .. "]: "
                    .. task_tostring(tasks[token])
            )
        end
    end
end

local function progress()
    local n = #vim.lsp.get_active_clients()
    if n <= 0 then
        return ""
    end

    local messages = {}
    for client_id, data in pairs(state.clients) do
        if vim.lsp.client_is_stopped(client_id) then
            -- if this client is stopped, clean it from state.clients
            state.clients[client_id] = nil
        else
            for token, task in pairs(data.tasks) do
                local tmp = task_format(task, data.name)
                log_debug(
                    "progress format message on client_id:" .. client_id .. ", token:" .. token .. ", content:" .. tmp
                )
                table.insert(messages, tmp)
            end
        end
    end
    if #messages > 0 then
        local tmp = table.concat(messages, config.seperator)
        log_debug("progress messages(" .. #messages .. "):" .. tmp)
        return config.sign .. " " .. tmp
    else
        log_debug("progress messages(" .. #messages .. "): no message")
        return config.sign
    end
end

local function setup(option)
    -- override default config
    config = vim.tbl_deep_extend("force", defaults, option or {})
    log_init()

    if not state.registered then
        if vim.lsp.handlers["$/progress"] then
            local old_handler = vim.lsp.handlers["$/progress"]
            vim.lsp.handlers["$/progress"] = function(...)
                old_handler(...)
                progress_handler(...)
            end
        else
            vim.lsp.handlers["$/progress"] = progress_handler
        end
        state.registered = true
    end
end

local M = {
    setup = setup,
    progress = progress,
}

return M
