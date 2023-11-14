local logger = require("lsp-progress.logger")

--- @type Configs
local Configs = {
    --- @type string?
    name = nil,
    --- @type integer?
    update_time_limit = nil,
    --- @type integer?
    regular_update_time = nil,
    --- @type boolean
    emit = false,
}

--- @class DisableEventOpt
--- @field mode string?
--- @field filetype string?
local DisableEventOpt = {
    mode = nil,
    filetype = nil,
}

--- @package
--- @param opts Configs
--- @return DisableEventOpt
function DisableEventOpt:new(opts)
    local o = {
        mode = opts.mode,
        filetype = opts.filetype,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

--- @package
--- @return boolean
function DisableEventOpt:match()
    local current_mode = vim.api.nvim_get_mode()
    local current_bufnr = vim.api.nvim_get_current_buf()
    local current_filetype = vim.fn.has("nvim-0.7") > 0
            and vim.api.nvim_get_option_value(
                "filetype",
                { buf = current_bufnr }
            )
        or vim.api.nvim_buf_get_option(current_bufnr, "filetype")
    -- logger.debug(
    --     "|lsp-progress.event - DisableEventOpt:match| current mode:%s, bufnr:%s, ft:%s, self:%s",
    --     vim.inspect(current_mode),
    --     vim.inspect(current_bufnr),
    --     vim.inspect(current_filetype),
    --     vim.inspect(self)
    -- )
    local mode_match = self.mode == "*" or self.mode == current_mode.mode
    local filetype_match = self.filetype == "*"
        or self.filetype == current_filetype
    return mode_match and filetype_match
end

--- @class DisableEventOptsManager
--- @field disable_event_opts DisableEventOpt[]
local DisableEventOptsManager = {
    disable_event_opts = {},
}

--- @package
--- @param opts Configs[]?
--- @return DisableEventOptsManager
function DisableEventOptsManager:new(opts)
    local disable_event_opts = {}
    if type(opts) == "table" then
        for _, o in ipairs(opts) do
            table.insert(disable_event_opts, DisableEventOpt:new(o))
        end
    end
    local o = {
        disable_event_opts = disable_event_opts,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

--- @package
--- @return boolean
function DisableEventOptsManager:match()
    for _, opt in ipairs(self.disable_event_opts) do
        if opt:match() then
            return true
        end
    end
    return false
end

--- @type DisableEventOptsManager?
local GlobalDisabledEventOptsManager = nil

--- @package
--- @return boolean
local function reset()
    Configs.emit = false
    return Configs.emit
end

--- @return boolean
local function emit()
    if not Configs.emit then
        if
            GlobalDisabledEventOptsManager == nil
            or not GlobalDisabledEventOptsManager:match()
        then
            vim.cmd("doautocmd <nomodeline> User " .. Configs.name)
            Configs.emit = true
            -- logger.debug("Emit user event:%s", Configs.name)
            -- else
            -- logger.debug("Disabled emit user event:%s", Configs.name)
        end
        vim.defer_fn(reset, Configs.update_time_limit --[[@as integer]])
    end
    return Configs.emit
end

local function regular_update()
    emit()
    vim.defer_fn(regular_update, Configs.regular_update_time --[[@as integer]])
end

--- @param event_name string
--- @param event_update_time_limit integer
--- @param internal_regular_update_time integer
--- @param disable_events_opts Configs[]?
local function setup(
    event_name,
    event_update_time_limit,
    internal_regular_update_time,
    disable_events_opts
)
    Configs.name = event_name
    Configs.update_time_limit = event_update_time_limit
    Configs.regular_update_time = internal_regular_update_time
    GlobalDisabledEventOptsManager =
        DisableEventOptsManager:new(disable_events_opts)
    reset()
    regular_update()
end

--- @type table<string, any>
local M = {
    setup = setup,
    emit = emit,
    reset = reset,
    DisableEventOpt = DisableEventOpt,
    DisableEventOptsManager = DisableEventOptsManager,
}

return M
