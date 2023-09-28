local logger = require("lsp-progress.logger")

--- @type Configs
local EventConfigs = {
    name = nil,
    update_time_limit = nil,
    regular_update_time = nil,
    emit = false,
}

--- @class DisableEventOpt
--- @field mode string?
--- @field filetype string?
local DisableEventOpt = {
    mode = nil,
    filetype = nil,
}

function DisableEventOpt:new(opts)
    return vim.tbl_deep_extend("force", vim.deepcopy(DisableEventOpt), {
        mode = opts.mode,
        filetype = opts.filetype,
    })
end

function DisableEventOpt:match()
    local current_mode = vim.api.nvim_get_mode()
    local current_bufnr = vim.api.nvim_get_current_buf()
    local current_filetype = vim.fn.has("nvim-0.7") > 0
            and vim.api.nvim_get_option_value(
                "filetype",
                { buf = current_bufnr }
            )
        ---@diagnostic disable-next-line: redundant-parameter
        or vim.api.nvim_buf_get_option(current_bufnr, "filetype")
    logger.debug(
        "|lsp-progress.event - DisableEventOpt:match| current_mode:%s, current_filetype:%s, self:%s",
        vim.inspect(current_mode),
        vim.inspect(current_filetype),
        vim.inspect(self)
    )
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

function DisableEventOptsManager:new(opts)
    local disable_event_opts = {}
    if type(opts) == "table" and #opts > 0 then
        for _, o in ipairs(opts) do
            table.insert(disable_event_opts, DisableEventOpt:new(o))
        end
    end
    return vim.tbl_deep_extend("force", vim.deepcopy(DisableEventOptsManager), {
        disable_event_opts = disable_event_opts,
    })
end

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

--- @return nil
local function reset()
    EventConfigs.emit = false
end

--- @return nil
local function emit()
    if not EventConfigs.emit then
        if
            GlobalDisabledEventOptsManager == nil
            or not GlobalDisabledEventOptsManager:match()
        then
            vim.cmd("doautocmd User " .. EventConfigs.name)
            EventConfigs.emit = true
            logger.debug("Emit user event:%s", EventConfigs.name)
        else
            logger.debug("Disabled emit user event:%s", EventConfigs.name)
        end
        vim.defer_fn(reset, EventConfigs.update_time_limit --[[@as integer]])
    end
end

local function regular_update()
    emit()
    vim.defer_fn(
        regular_update,
        EventConfigs.regular_update_time --[[@as integer]]
    )
end

--- @param event_name string
--- @param event_update_time_limit integer
--- @param internal_regular_update_time integer
--- @param disable_events_opts table[]?
--- @return nil
local function setup(
    event_name,
    event_update_time_limit,
    internal_regular_update_time,
    disable_events_opts
)
    EventConfigs.name = event_name
    EventConfigs.update_time_limit = event_update_time_limit
    EventConfigs.regular_update_time = internal_regular_update_time
    GlobalDisabledEventOptsManager =
        DisableEventOptsManager:new(disable_events_opts)
    reset()
    regular_update()
end

--- @type table<string, any>
local M = {
    setup = setup,
    emit = emit,
}

return M
