--
-- eventable.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local _select, _pack, _unpack = select, table.pack, table.unpack or unpack

if not _pack then
   _pack = function (...)
      local n = _select("#", ...)
      local r = { n = n }
      for i = 1, n do
         r[i] = _select(i, ...)
      end
      return r
   end
end

local function _expack (args, ...)
   local r = { n = args.n }
   local n = _select("#", ...)
   for i = 1, args.n do
      r[i] = args[i]
   end
   for i = 1, n do
      r[r.n + i] = _select(i, ...)
   end
   r.n = r.n + n
   return _unpack(r)
end

local log = (function ()
   local env_value = os.getenv("MATRIX_EVENTABLE_DEBUG_LOG")
   if env_value and #env_value > 0 and env_value ~= "0" then
      local out, _tostring = io.stderr, tostring
      return function (...)
         out:write("[eventable]")
         local args = _pack(...)
         for i = 1, args.n do
            out:write(" " .. _tostring(args[i]))
         end
         out:write("\n")
         out:flush()
      end
   else
      return function (...) end
   end
end)()

local function eventable_functions (...)
   local event_map = {}

   local hook = function (event, handler)
      log("hook:", event, handler)
      if not handler then
         event_map[event] = nil
      else
         if not event_map[event] then
            event_map[event] = {}
         end
         local handlers = event_map[event]
         handlers[#handlers + 1] = handler
      end
   end

   local unhook = function (event, handler)
      log("unhook:", event, handler)
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

   local fire

   local nargs = _select("#", ...)
   if nargs == 0 then
      -- Simplest version, no arguments.
      fire = function (event, ...)
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
   elseif nargs == 1 then
      -- Common single-argument case: optimized.
      local arg = _select(1, ...)
      fire = function (event, ...)
         log("fire: " .. event .. ":", arg, ...)
         local handlers = event_map[event]
         if handlers then
            for i = 1, #handlers do
               local ret = _pack(handlers[i](arg, ...))
               if ret.n > 0 then
                  return _unpack(ret)
               end
            end
         end
      end
   else
      -- Generic multi-argument case.
      local args = _pack(...)
      fire = function (event, ...)
         log("fire: " .. event .. ":", _expack(args, ...))
         local handlers = event_map[event]
         if handlers then
            for i = 1, #handlers do
               local ret = _pack(handlers[i](_expack(args, ...)))
               if ret.n > 0 then
                  return _unpack(ret)
               end
            end
         end
      end
   end

   return fire, hook, unhook
end

local function eventable_object(obj)
   local fire, hook, unhook = eventable_functions()
   function obj:fire(name, ...)
      return fire(name, self, ...)
   end
   function obj:hook(...)
      hook(...)
      return self  -- Allow chaining
   end
   function obj:unhook(...)
      unhook(...)
      return self  -- Allow chaining
   end
   return obj
end

return {
   functions = eventable_functions,
   object    = eventable_object,
}
