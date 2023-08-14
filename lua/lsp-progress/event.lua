--- @type table<string, any>
local logger = require("lsp-progress.logger")

--- @type string|nil
local EventName = nil
--- @type integer?
local EventUpdateTimeLimit = nil
--- @type table<string, boolean>?
local DisabledModes = nil
--- @type table<string, boolean>?
local DisabledFiletypes = nil
--- @type boolean
local EventEmit = false

--- @return nil
local function reset()
    EventEmit = false
end

--- @return nil
local function emit()
    if not EventEmit then
        EventEmit = true
        local m = vim.api.nvim_get_mode()
        local bufnr = vim.api.nvim_get_current_buf()
        local ft = nil
        if vim.fn.has("nvim-0.7") > 0 then
            ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
        else
            ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
        end
        logger.debug(
            "mode:%s, disabledModes:%s, bufnr:%s, filetype:%s",
            vim.inspect(m),
            vim.inspect(DisabledModes),
            vim.inspect(bufnr),
            vim.inspect(ft)
        )
        if
            (type(DisabledModes) ~= "table" or not DisabledModes[m.mode])
            and (
                type(DisabledFiletypes) ~= "table" or not DisabledFiletypes[ft]
            )
        then
            vim.cmd("doautocmd User " .. EventName)
            logger.debug("Emit user event:%s", EventName)
        else
            logger.debug("Disabled emit user event:%s", EventName)
        end
        vim.defer_fn(reset, EventUpdateTimeLimit --[[@as integer]])
    end
end

--- @param event_name string
--- @param event_update_time_limit integer
--- @param disabled_modes string[]?
--- @return nil
local function setup(
    event_name,
    event_update_time_limit,
    disabled_modes,
    disabled_filetypes
)
    EventName = event_name
    EventUpdateTimeLimit = event_update_time_limit
    if type(disabled_modes) == "table" and #disabled_modes > 0 then
        DisabledModes = {}
        for _, m in ipairs(disabled_modes) do
            if type(m) == "string" and string.len(m) > 0 then
                DisabledModes[m] = true
            end
        end
    end
    if type(disabled_filetypes) == "table" and #disabled_filetypes > 0 then
        DisabledFiletypes = {}
        for _, ft in ipairs(disabled_filetypes) do
            if type(ft) == "string" and string.len(ft) > 0 then
                DisabledFiletypes[ft] = true
            end
        end
    end
    reset()
end

--- @type table<string, any>
local M = {
    setup = setup,
    emit = emit,
}

return M