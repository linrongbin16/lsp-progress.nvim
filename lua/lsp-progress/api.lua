local M = {}

M.lsp_clients = function()
    return vim.lsp.get_clients()
end

--- @param client_id integer
--- @return boolean
M.lsp_client_is_stopped = function(client_id)
    return vim.lsp.get_client_by_id(client_id) == nil
end

return M
