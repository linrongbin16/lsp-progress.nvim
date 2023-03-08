local logger = require("lsp-progress.logger")

local ClientObject = {
    client_id = nil,
    client_name = nil,
    spin_index = 0,
    serieses = {},
}

function ClientObject:has_series(token)
    return self.serieses[token] ~= nil
end

function ClientObject:remove_series(token)
    self.serieses[token] = nil
end

function ClientObject:get_series(token)
    return self.serieses[token]
end

function ClientObject:add_series(token, series)
    self.serieses[token] = series
end

function ClientObject:empty()
    return next(self.serieses)
end

function ClientObject:increase_spin_index(spinner_length)
    local old = self.spin_index
    self.spin_index = (self.spin_index + 1) % spinner_length
    logger.debug("Client spin index:%d => %d", old, self.spin_index)
end

local function new_client(client_id, client_name)
    local client = vim.tbl_extend(
        "force",
        vim.deepcopy(ClientObject),
        { client_id = client_id, client_name = client_name }
    )
    return client
end

local M = {
    new_client = new_client,
}

return M
