local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local logger = require("lsp-progress.logger")

ClientRecord = {}












ClientRecordFormatterType = {}
local ClientRecordFormatter = nil
local Spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

function ClientRecord:formatted_result()
   return self._formatted
end

function ClientRecord:tostring()
   return string.format("[%s-%s]", tostring(self.name), tostring(self.id))
end

function ClientRecord:has_series(token)
   return self.serieses[token] ~= nil
end

function ClientRecord:get_series(token)
   return self.serieses[token]
end

function ClientRecord:format()
   local series_messages = {}
   local visited_tokens = {}
   for tt, message_tokens in pairs(self._deduped_tokens) do
      message_tokens = message_tokens
      for ms, token in pairs(message_tokens) do
         if not visited_tokens[token] then
            if self:has_series(token) then
               local series = self:get_series(token)
               local result = series:formatted_result()
               logger.debug(
               "|client.ClientRecord.format| get series %s (deduped key: %s-%s) format result in client %s: %s",
               series:tostring(),
               tt,
               ms,
               self:tostring(),
               vim.inspect(series_messages))

               if result then
                  table.insert(series_messages, result)
               end
            end
            visited_tokens[token] = true
         end
      end
   end
   if type(ClientRecordFormatter) == "function" then
      self._formatted = ClientRecordFormatter(
      self.name,
      Spinner[self.spin_index + 1],
      series_messages)

   end
   logger.debug(
   "|client.ClientRecord.format| format client %s: %s",
   self:tostring(),
   vim.inspect(self._formatted))

   return self._formatted
end

function ClientRecord:_has_deduped_token(title, message)
   title = tostring(title)
   message = tostring(message)
   if not self._deduped_tokens[title] then
      return false
   end
   if not self._deduped_tokens[title][message] then
      return false
   end
   return true
end

function ClientRecord:_set_deduped_token(title, message, token)
   title = tostring(title)
   message = tostring(message)
   if not self._deduped_tokens[title] then
      self._deduped_tokens[title] = {}
   end
   self._deduped_tokens[title][message] = token
end

function ClientRecord:_remove_deduped_token(title, message)
   title = tostring(title)
   message = tostring(message)
   if not self._deduped_tokens[title] then
      return
   end
   self._deduped_tokens[title][message] = nil
end

function ClientRecord:_get_deduped_token(title, message)
   title = tostring(title)
   message = tostring(message)
   return self._deduped_tokens[title][message]
end

function ClientRecord:remove_series(token)
   if self:has_series(token) then
      local series = self:get_series(token)
      if
self:_has_deduped_token(series.title, series.message) and
         self:_get_deduped_token(series.title, series.message) == token then

         self:_remove_deduped_token(series.title, series.message)
      end
   end
   self.serieses[token] = nil
   self:format()
end

function ClientRecord:add_series(token, series)
   self:_set_deduped_token(series.title, series.message, token)
   self.serieses[token] = series
   self:format()
end

function ClientRecord:empty()
   return next(self.serieses)
end

function ClientRecord:increase_spin_index()
   local old = self.spin_index
   self.spin_index = (self.spin_index + 1) % #Spinner
   logger.debug(
   "|client.ClientRecord.increase_spin_index| client %s spin index:%d => %d",
   self:tostring(),
   old,
   self.spin_index)

   self:format()
end

local function setup(client_formatter, spinner)
   ClientRecordFormatter = client_formatter
   Spinner = spinner
end

local function new_client(id, name)
   local self = setmetatable({}, { __index = ClientRecord })
   self.id = id
   self.name = name
   self.spin_index = 0
   self.serieses = {}
   self._formatted = nil
   self._deduped_tokens = {}
   self:format()
   return self
end

local M = {
   setup = setup,
   new_client = new_client,
}

return M
