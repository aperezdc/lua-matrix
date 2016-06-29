#! /usr/bin/env lua
--
-- eventable.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local eventable = require "matrix.eventable"

do -- Simple event
   local ev = assert(eventable())
   local flag = false
   ev.hook("foo", function () flag = true end)
   ev.fire("foo")
   assert(flag)
end

do -- Stop at first handler that returns some value
   local ev = assert(eventable())
   local flag1, flag2, flag3 = false, false, false
   ev.hook("foo", function () flag1 = true end)
   ev.hook("foo", function () flag2 = true ; return 42 end)
   ev.hook("foo", function () flag3 = true ; return 0 end)
   assert(ev.fire("foo") == 42)
   assert(flag1 == true)
   assert(flag2 == true)
   assert(flag3 == false)
end

do -- Arguments to eventable() are passed to handlers
   local obj = { answer = 42 }
   local ev = assert(eventable(obj))
   ev.hook("foo", function (o)
      assert(o == obj)
      assert(o.answer == 42)
      o.answer = 0  -- Mutate
   end)
   ev.fire("foo")
   assert(obj.answer == 0)
end

do -- Multiple arguments passed to eventable
   local ev = assert(eventable(42, "bar", nil, { v=10 }))
   ev.hook("foo", function (a, s, n, o)
      assert(a == 42)
      assert(s == "bar")
      assert(n == nil)
      assert(o.v == 10)
   end)
   ev.fire("foo")
end
