local EventName:string|nil = nil
local EventUpdateTimeLimit:integer|nil = nil
local EventEmit = false

local function reset():nil
    EventEmit = false
end

local function emit():nil
    if not EventEmit then
        EventEmit = true
        vim.cmd("doautocmd User " .. EventName)
        vim.defer_fn(reset, EventUpdateTimeLimit)
        logger.debug("|event.emit| emit user event:%s", EventName)
    end
end

local function setup(event_name:string, event_update_time_limit:integer):nil
    EventName = event_name
    EventUpdateTimeLimit = event_update_time_limit
    reset()
end

local M:table = {
    setup = setup,
    emit = emit,
}

return M
