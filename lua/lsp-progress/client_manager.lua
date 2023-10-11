local logger = require("lsp-progress.logger")
local Client = require("lsp-progress.client").Client

--- @class ClientManager
--- @field clients table<integer, Client>
local ClientManager = {}

--- @return ClientManager
function ClientManager:new()
    local o = {
        clients = {},
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

--- @param client_id integer
--- @return boolean
function ClientManager:has(client_id)
    return self.clients[client_id] ~= nil
end

--- @param client_id integer
--- @return Client
function ClientManager:get(client_id)
    return self.clients[client_id]
end

--- @return boolean
function ClientManager:empty()
    return not next(self.clients)
end

--- @param client_id integer
function ClientManager:remove(client_id)
    self.clients[client_id] = nil
    if self:empty() then
        self.clients = {}
    end
end

--- @param client_id integer
--- @param client_name string
--- @return nil
function ClientManager:register(client_id, client_name)
    if not self:has(client_id) then
        self.clients[client_id] = Client:new(client_id, client_name)
        logger.debug(
            "|client_manager - ClientManager:register| register: %s",
            vim.inspect(self.clients[client_id])
        )
    end
end

local M = {
    ClientManager = ClientManager,
}

return M
