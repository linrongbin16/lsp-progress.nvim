-- Credit:
--  * https://github.com/nvim-lua/lsp-status.nvim
--  * https://github.com/j-hui/fidget.nvim

local defaults = {
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    update_time = 200,
    sign = " LSP", -- nf-fa-gear \uf013
    seperator = " ",
    decay = 1000,
    event = "LspProgressStatusUpdate",
}
local config = {}
local state = {
    registered = false,
    datamap = {}, -- client_id => data { name, tasks }
    cache = nil,
}

-- {
-- util

local function log_warn(msg)
    vim.cmd("echohl WarningMsg")
    vim.cmd(string.format("[lsp-progress.nvim] %s", msg))
    vim.cmd("echohl None")
end

local function emit_event()
    vim.cmd("doautocmd User " .. config.event)
end

local function reset_cache()
    state.cache = nil
    -- emit an event to user immediately after clean cache
    emit_event()
end

-- }

-- {
-- task

local function task_new(title, message, percentage)
    return { title = title, message = message, percentage = percentage, index = 1, done = false }
end

local function task_update(task, message, percentage)
    task.message = message
    task.percentage = percentage
    task.index = (task.index + 1) % #config.spinner + 1
end

local function task_done(task, message)
    task.message = message
    task.index = nil
    task.done = true
end

local function task_spin(task)
    task.index = task.index + 1
end

local function task_format(task, name)
    local builder = { "[" .. name .. "]" }
    if task.index then
        table.insert(builder, config.spinner[task.index])
    end
    if task.title and task.title ~= "" then
        table.insert(builder, task.title)
    end
    if task.message and task.message ~= "" then
        table.insert(builder, task.message)
    end
    if task.percentage then
        table.insert(builder, string.format("(%.0f%%%%)", task.percentage))
    end
    if task.done then
        table.insert(builder, "- done")
    end
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
    local function again()
        spin(client_id, token)
    end

    if not state.datamap[client_id] then
        return
    end
    local data = state.datamap[client_id]
    if not data.tasks[token] then
        return
    end
    local task = data.tasks[token]

    task_spin(task)
    emit_event() -- notify user

    if not task.done then
        -- task not done, continue next spin
        vim.defer_fn(again, config.update_time)
    else
        local function remove_task_defer()
            if not state.datamap[client_id] then
                return
            end
            if not state.datamap[client_id].tasks[token] then
                state.datamap[client_id].tasks[token] = nil
                emit_event() -- notify user
            end
        end

        -- task done, remove this task from data in decay time
        vim.defer_fn(remove_task_defer, config.decay)
    end
end

local function progress_handler(err, msg, ctx)
    local client_id = ctx.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return
    end
    local client_name = not client and client.name or "null"

    -- register client id if not exist
    if not state.datamap[client_id] then
        state.datamap[client_id] = data_new(client_name)
    end

    local value = msg.value
    local token = msg.token

    if not value.kind then
        return
    end

    local tasks = state.datamap[client_id].tasks
    if value.kind == "begin" then
        -- add task
        tasks[token] = task_new(value.title, value.message, value.percentage)
        -- start spin
        spin(client_id, token)
    elseif value.kind == "report" then
        task_update(tasks[token], value.message, value.percentage)
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
        end
    end
end

local function progress()
    local n = #vim.lsp.get_active_clients()
    if n <= 0 then
        return ""
    end

    local messages = {}
    for client_id, data in pairs(state.datamap) do
        if not vim.lsp.client_is_stopped(client_id) then
            for token, task in pairs(data.tasks) do
                table.insert(messages, task_format(task, data.name))
            end
        end
    end
    if #messages > 0 then
        return config.sign .. " " .. table.concat(messages, config.seperator)
    else
        return config.sign
    end
end

local function setup(option)
    -- override default config
    config = vim.tbl_deep_extend("force", defaults, option or {})

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
