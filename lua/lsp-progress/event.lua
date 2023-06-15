--- @type table<string, any>
local logger = require("lsp-progress.logger")

--- @type string|nil
local EventName = nil
--- @type integer|nil
local EventUpdateTimeLimit = nil
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
        vim.cmd("doautocmd User " .. EventName)
        vim.defer_fn(reset, EventUpdateTimeLimit)
        logger.debug("Emit user event:%s", EventName)
    end
end

--- @param event_name string
--- @param event_update_time_limit integer
--- @return nil
local function setup(event_name, event_update_time_limit)
    EventName = event_name
    EventUpdateTimeLimit = event_update_time_limit
    reset()
end

--- @type table<string, any>
local M = {
    setup = setup,
    emit = emit,
}

return M