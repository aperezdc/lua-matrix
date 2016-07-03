--
-- eventable.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local _select, _pack, _unpack = select, table.pack, table.unpack or unpack

if not _pack then
   -- Provide a table.pack() implementation for Lua 5.1 and LuaJIT.
   _pack = function (...)
      local n = _select("#", ...)
      local r = { n = n }
      for i = 1, n do
         r[i] = _select(i, ...)
      end
      return r
   end
end

local log = (function ()
   local env_value = os.getenv("MATRIX_EVENTABLE_DEBUG_LOG")
   if env_value and #env_value > 0 and env_value ~= "0" then
      local out, _tostring = io.stderr, tostring
      return function (...)
         out:write("[eventable]")
         local n = _select("#", ...)
         for i = 1, n do
            out:write(" " .. _tostring(_select(i, ...)))
         end
         out:write("\n")
         out:flush()
      end
   else
      return function (...) end
   end
end)()

local function do_hook(event_map, event, handler)
   log("hook:", event, handler)
   if handler then
      if not event_map[event] then
         event_map[event] = {}
      end
      local handlers = event_map[event]
      handlers[#handlers + 1] = handler
   else
      return event_map[event]
   end
end

local function do_unhook(event_map, event, handler)
   log("unhook:", event, handler)
   if handler == nil then
      event_map[event] = nil
      return
   end
   local old_handlers = event_map[event]
   if old_handlers then
      local handlers = {}
      for i = 1, #old_handlers do
         local h = old_handlers[i]
         if h ~= handler then
            handlers[#handlers + 1] = h
         end
      end
      event_map[event] = handlers
   end
end

local function do_fire(event_map, event, ...)
   log("fire: " .. event .. ":", ...)
   local handlers = event_map[event]
   if handlers then
      for i = 1, #handlers do
         local ret = _pack(handlers[i](...))
         if ret.n > 0 then
            return _unpack(ret)
         end
      end
   end
end

local function eventable_functions (event_map)
   if not event_map then event_map = {} end
   return function (e, ...) return do_fire(event_map, e, ...) end,
          function (e, h) return do_hook(event_map, e, h) end,
          function (e, h) return do_unhook(event_map, e, h) end
end

local function eventable_object(obj, event_map)
   if not obj then obj = {} end
   if not event_map then event_map = {} end
   function obj:fire(e, ...)
      return do_fire(event_map, e, self, ...)
   end
   function obj:hook(...)
      do_hook(event_map, ...)
      return self  -- Allow chaining
   end
   function obj:unhook(...)
      do_unhook(event_map, ...)
      return self  -- Allow chaining
   end
   return obj
end

return {
   functions = eventable_functions,
   object    = eventable_object,
}
