-- Credit:
--  * https://github.com/nvim-lua/lsp-status.nvim
--  * https://github.com/j-hui/fidget.nvim

local global_config = {
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    update_time = 125,
    sign = " [LSP]", -- nf-fa-gear \uf013
    seperator = " ┆ ",
    decay = 1000,
    event = "LspProgressStatusUpdate",
}
local global_state = {
    registered = false,
    redrawed = false,
    data = {},
    cache = nil,
}

local function reset_last_redraw()
    global_state.redrawed = false
end

local function reset_cache()
    global_state.cache = nil
end

local function register_client(id, name)
    -- register client id if not exist
    if not global_state.data[id] then
        global_state.data[id] = {
            name = name,
            once_messages = {},
            progress_messages = {},
        }
    end
end

local function progress_handler(err, msg, ctx)
    local client_id = ctx.client_id
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return
    end
    local client_name = not client and client.name or "null"

    register_client(client_id, client_name)
    local value = msg.value
    local token = msg.token

    if value.kind then
        -- progress message

        local pm = global_state.data[client_id].progress_messages
        if value.kind == "begin" then
            -- force begin messages redraw, so here we reset redraw flag
            global_state.redrawed = false

            pm[token] = {
                title = value.title,
                message = value.message,
                percentage = value.percentage,
                spinner_index = 1,
                done = false,
            }
        elseif value.kind == "report" then
            pm[token].message = value.message
            pm[token].percentage = value.percentage
            pm[token].spinner_index = (pm[token].spinner_index + 1) % #global_config.spinner + 1
        elseif value.kind == "end" then
            -- force begin messages redraw, so here we reset lastRedraw
            global_state.redrawed = false
            if pm[token] == nil then
                vim.cmd("echohl WarningMsg")
                vim.cmd(
                    "[lsp-progress.nvim] Received `end` message with no corressponding `begin` from client_id:"
                        .. client_id
                        .. "!"
                )
                vim.cmd("echohl None")
            else
                pm[token].message = value.message
                pm[token].done = true
                pm[token].spinner_index = nil
            end
        end
    else
        -- once message

        -- force once messages redraw, so here we reset lastRedraw
        global_state.redrawed = false
        table.insert(global_state.data.once_messages, { client_id = client_id, content = value, shown = 0 })
    end

    -- if last redraw in update time threshold, skip this redraw
    if global_state.redrawed then
        return
    end

    -- if redraw timeout, trigger lualine redraw, and defer until next time
    vim.cmd("doautocmd User " .. global_config.event)
    global_state.redrawed = true
    vim.defer_fn(reset_last_redraw, global_config.update_time)
end

local function progress()
    local client_count = #vim.lsp.get_active_clients()
    if client_count <= 0 then
        return ""
    end

    local new_messages = {}
    local remove_progress = {}
    local remove_once = {}
    for client_id, data in pairs(global_state.data) do
        if not vim.lsp.client_is_stopped(client_id) then
            for token, ctx in pairs(data.progress_messages) do
                table.insert(new_messages, {
                    progress_message = true,
                    name = data.name,
                    title = ctx.title,
                    message = ctx.message,
                    percentage = ctx.percentage,
                    spinner_index = ctx.spinner_index,
                })
                if ctx.done then
                    table.insert(remove_progress, { client_id = client_id, token = token })
                end
            end
            for i, once_msg in ipairs(data.once_messages) do
                once_msg.shown = once_msg.shown + 1
                if once_msg.shown > 1 then
                    table.insert(remove_once, { client_id = client_id, index = i })
                end
                table.insert(new_messages, { once_message = true, name = data.name, content = once_msg.content })
            end
        end
    end

    for _, item in ipairs(remove_once) do
        table.remove(global_state.data[item.client_id].once_messages, item.index)
    end
    for _, item in ipairs(remove_progress) do
        global_state.data[item.client_id].progress_messages[item.token] = nil
    end

    local current = ""
    if #new_messages > 0 then
        local buffer = {}
        for i, msg in ipairs(new_messages) do
            local builder = { "[" .. msg.name .. "]" }
            if msg.progress_message then
                if msg.spinner_index then
                    table.insert(builder, global_config.spinner[msg.spinner_index])
                end
                if msg.title and msg.title ~= "" then
                    table.insert(builder, msg.title)
                end
                if msg.message and msg.message ~= "" then
                    table.insert(builder, msg.message)
                end
                if msg.percentage then
                    table.insert(builder, string.format("(%.0f%%%%)", msg.percentage))
                end
            elseif msg.once_message then
                if msg.content and msg.content ~= "" then
                    table.insert(builder, msg.content)
                end
            end
            table.insert(buffer, table.concat(builder, " "))
        end
        current = " " .. table.concat(buffer, global_config.seperator)
    end

    if current ~= nil and current ~= "" then
        -- if has valid current message, cache it and return
        global_state.cache = current
        return global_config.sign .. current
    else
        -- if current message gone, but cache is still there
        if global_state.cache ~= nil and global_state.cache ~= "" then
            -- reset cache in decay
            vim.defer_fn(reset_cache, global_config.decay)
            -- return cache message
            return global_config.sign .. global_state.cache
        else
            -- if current message is gone, and cache is gone, return ''
            return global_config.sign .. ""
        end
    end
end

local function override_config(config)
    if config["spinner"] then
        global_config.spinner = config["spinner"]
    end
    if config["update_time"] then
        global_config.update_time = config["update_time"]
    end
    if config["sign"] then
        global_config.sign = config["sign"]
    end
    if config["seperator"] then
        global_config.seperator = config["seperator"]
    end
    if config["decay"] then
        global_config.decay = config["decay"]
    end
    if config["event"] then
        global_config.event = config["event"]
    end
end

local function setup(config)
    -- override default config
    override_config(config)

    if not global_state.registered then
        if vim.lsp.handlers["$/progress"] then
            local old_handler = vim.lsp.handlers["$/progress"]
            vim.lsp.handlers["$/progress"] = function(...)
                old_handler(...)
                progress_handler(...)
            end
        else
            vim.lsp.handlers["$/progress"] = progress_handler
        end
        global_state.registered = true
    end
end

local M = {
    setup = setup,
    progress = progress,
}

return M
