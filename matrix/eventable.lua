#! /usr/bin/env lua
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

return function (...)
   local event_map = {}
   local events = {}

   function events.hook(event, handler)
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

   local nargs = _select("#", ...)
   if nargs == 0 then
      -- Simplest version, no arguments.
      function events.fire(event, ...)
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
      function events.fire(event, ...)
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
      function events.fire(event, ...)
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

   return events
end
