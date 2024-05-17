---@diagnostic disable: deprecated
local NVIM_VERSION_010 = vim.fn.has("nvim-0.10") > 0

local M = {}

M.lsp_clients = function()
    if NVIM_VERSION_010 then
        return vim.lsp.get_clients()
    else
        return vim.lsp.get_active_clients()
    end
end

return M
