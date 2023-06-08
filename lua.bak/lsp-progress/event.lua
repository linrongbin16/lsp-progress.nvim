local logger = require("lsp-progress.logger")

local EventName = nil
local EventUpdateTimeLimit = nil
local EventEmit = false

local function reset()
    EventEmit = false
end

local function emit()
    if not EventEmit then
        EventEmit = true
        vim.cmd("doautocmd User " .. EventName)
        vim.defer_fn(reset, EventUpdateTimeLimit)
        logger.debug("Emit user event:%s", EventName)
    end
end

local function setup(event_name, event_update_time_limit)
    EventName = event_name
    EventUpdateTimeLimit = event_update_time_limit
    reset()
end

local M = {
    setup = setup,
    emit = emit,
}

return M