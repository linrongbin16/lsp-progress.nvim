---@diagnostic disable: deprecated
local NVIM_VERSION_010 = vim.fn.has("nvim-0.10") > 0
local NVIM_VERSION_012 = vim.fn.has("nvim-0.12") > 0

local M = {}

M.lsp_clients = function()
    if NVIM_VERSION_010 then
        return vim.lsp.get_clients()
    else
        return vim.lsp.get_active_clients()
    end
end

--- @param client_id integer
--- @return boolean
M.lsp_client_is_stopped = function(client_id)
    if NVIM_VERSION_012 then
        return vim.lsp.get_client_by_id(client_id) == nil
    else
        return vim.lsp.client_is_stopped(client_id)
    end
end

return M
