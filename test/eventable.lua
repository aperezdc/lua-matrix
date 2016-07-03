--
-- eventable.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local eventable = require "matrix.eventable"

do -- Simple event
   local fire, hook = assert(eventable.functions())
   local flag = false
   hook("foo", function () flag = true end)
   fire("foo")
   assert(flag)
end

do -- Stop at first handler that returns some value
   local fire, hook = assert(eventable.functions())
   local flag1, flag2, flag3 = false, false, false
   hook("foo", function () flag1 = true end)
   hook("foo", function () flag2 = true ; return 42 end)
   hook("foo", function () flag3 = true ; return 0 end)
   assert(fire("foo") == 42)
   assert(flag1 == true)
   assert(flag2 == true)
   assert(flag3 == false)
end

do -- Arguments to eventable() are passed to handlers
   local obj = { answer = 42 }
   local fire, hook = assert(eventable.functions(obj))
   hook("foo", function (o)
      assert(o == obj)
      assert(o.answer == 42)
      o.answer = 0  -- Mutate
   end)
   fire("foo")
   assert(obj.answer == 0)
end

do -- Multiple arguments passed to eventable
   local fire, hook = assert(eventable.functions(42, "bar", nil, { v=10 }))
   hook("foo", function (a, s, n, o)
      assert(a == 42)
      assert(s == "bar")
      assert(n == nil)
      assert(o.v == 10)
   end)
   fire("foo")
end

do -- Unhooking should work
   local flag1, flag2 = false, false
   local h1 = function () flag1 = true end
   local h2 = function () flag2 = true end

   local fire, hook, unhook = assert(eventable.functions())
   hook("foo", h1)
   hook("foo", h2)
   fire("foo")
   assert(flag1 == true)
   assert(flag2 == true)

   flag1, flag2 = false, false
   unhook("foo", h2)
   fire("foo")
   assert(flag1 == true)
   assert(flag2 == false)

   flag1, flag2 = false, false
   unhook("foo")
end
