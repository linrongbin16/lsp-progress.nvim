local Defaults = {
    -- Spinning icons.
    spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    -- Spinning update time in milliseconds.
    spin_update_time = 200,
    -- Last message cached decay time in milliseconds.
    --
    -- Message could be really fast(appear and disappear in an
    -- instant) that user cannot even see it, thus we cache the last message
    -- for a while for user view.
    decay = 1000,
    -- User event name.
    event = "LspProgressStatusUpdated",
    -- Event update time limit in milliseconds.
    --
    -- Sometimes progress handler could emit many events in an instant, while
    -- refreshing statusline cause too heavy synchronized IO, so we limit the
    -- event rate to reduce this cost.
    event_update_time_limit = 125,
    --- Max progress string length, by default -1 is unlimit.
    max_size = -1,
    -- Format series message.
    --
    -- By default it looks like: `formatting isort (100%) - done`.
    --
    -- @param title      Message title.
    -- @param message    Message body.
    -- @param percentage Progress in percentage numbers: [0%-100%].
    -- @param done       Indicate if this message is the last one in progress.
    -- @return           A nil|string|table value. The returned value will be
    --                   passed to function `client_format` as one of the
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
    -- Format client message.
    --
    -- By default it looks like:
    -- `[null-ls] ⣷ formatting isort (100%) - done, formatting black (50%)`.
    --
    -- @param client_name     Client name.
    -- @param spinner         Spinner icon.
    -- @param series_messages Series messages array.
    -- @return                A nil|string|table value. The returned value will
    --                        be passed to function `format` as one of the
    --                        `client_messages` array, or ignored if return nil.
    client_format = function(client_name, spinner, series_messages)
        return #series_messages > 0
                and ("[" .. client_name .. "] " .. spinner .. " " .. table.concat(
                    series_messages,
                    ", "
                ))
            or nil
    end,
    -- Format (final) message.
    --
    -- By default it looks like:
    -- ` LSP [null-ls] ⣷ formatting isort (100%) - done, formatting black (50%)`
    --
    -- @param client_messages Client messages array.
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
    --- Print log to console(command line).
    console_log = true,
    --- Print log to file.
    file_log = false,
    -- Log file to write, work with `file_log=true`.
    -- For Windows: `$env:USERPROFILE\AppData\Local\nvim-data\lsp-progress.log`.
    -- For *NIX: `~/.local/share/nvim/lsp-progress.log`.
    file_log_name = "lsp-progress.log",
}

local function setup(option)
    local config =
        vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})
    return config
end

local M = {
    setup = setup,
}

return M
