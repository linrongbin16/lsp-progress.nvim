local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local Defaults = {

   spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

   spin_update_time = 200,





   decay = 1000,

   event = "LspProgressStatusUpdated",





   event_update_time_limit = 100,

   max_size = -1,











   series_format = function(title, message, percentage, done)
      local builder = {}
      local has_title = false
      local has_message = false
      if title and title ~= "" then
         table.insert(builder, title)
         has_title = true
      end
      if message and message ~= "" then
         table.insert(builder, message)
         has_message = true
      end
      if percentage and (has_title or has_message) then
         table.insert(builder, string.format("(%.0f%%%%)", percentage))
      end
      if done and (has_title or has_message) then
         table.insert(builder, "- done")
      end
      return table.concat(builder, " ")
   end,











   client_format = function(client_name, spinner, series_messages)
      return #series_messages > 0 and
      ("[" .. client_name .. "] " .. spinner .. " " .. table.concat(
      series_messages,
      ", ")) or

      nil
   end,








   format = function(client_messages)
      local sign = " LSP"
      return #client_messages > 0 and
      (sign .. " " .. table.concat(client_messages, " ")) or
      sign
   end,

   debug = false,

   console_log = true,

   file_log = false,



   file_log_name = "lsp-progress.log",
}

local function setup(option)
   local config = 
   vim.tbl_deep_extend("force", vim.deepcopy(Defaults), option or {})
   return config
end

local M = {
   setup = setup,
}

return M
