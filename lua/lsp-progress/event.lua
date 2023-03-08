local logger = require("lsp-progress.logger")

local EventEmit = false

local function reset()
    EventEmit = false
end

local function emit(event, update_limit)
    if not EventEmit then
        EventEmit = true
        vim.cmd("doautocmd User " .. event)
        vim.defer_fn(reset, update_limit)
        logger.debug("Emit user event:%s", event)
    end
end

local M = {
    reset = reset,
    emit = emit,
}

return M
