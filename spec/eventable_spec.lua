--
-- eventable.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local eventable = require "matrix.eventable"

describe("matrix.eventable", function ()
   it("can be imported", function ()
      assert.is.table(eventable)
   end)

   it("has a matrix.eventable.functions function", function ()
      assert.is_function(eventable.functions)
   end)

   it("has a matrix.eventable.object function", function ()
      assert.is_function(eventable.object)
   end)
end)

describe("matrix.eventable.functions()", function ()
   it("returns three callable functions", function ()
      local s = spy.new(eventable.functions)
      local fire, hook, unhook = s()
      assert.spy(s).returned_with(
         match.is_function(),
         match.is_function(),
         match.is_function())
   end)

   it("calls hooked handlers when firing events", function ()
      local flag = false
      local handler = spy.new(function () flag = true end)

      local fire, hook = assert(eventable.functions())
      hook("foo", handler)
      fire("foo")

      assert.spy(handler).was_called(1)
      assert.is_true(flag)
   end)

   it("stops at first handler that returs some value", function ()
      local fire, hook = assert(eventable.functions())
      local flag1, flag2, flag3 = false, false, false
      hook("foo", function () flag1 = true end)
      hook("foo", function () flag2 = true ; return 42 end)
      hook("foo", function () flag3 = true ; return 0 end)
      assert.is_equal(42, fire("foo"))
      assert.is_true(flag1)
      assert.is_true(flag2)
      assert.is_false(flag3)
   end)

   it("accepts a table where to store the event map", function ()
      local events = {}
      local fire, hook = assert(eventable.functions(events))
      hook("foo", function () end)
      assert.truthy(events.foo)
   end)

   it("allows unhooking a handler", function ()
      local fire, hook, unhook = assert(eventable.functions())

      local h1 = spy.new(function () end)
      local h2 = spy.new(function () end)
      hook("foo", h1)
      hook("foo", h2)
      fire("foo")
      assert.spy(h1).was_called(1)
      assert.spy(h2).was_called(1)

      unhook("foo", h2)
      fire("foo")
      assert.spy(h1).was_called(2)
      assert.spy(h2).was_called(1)
   end)
end)

describe("matrix.eventable.object()", function ()
   it("creates a new table when no parameters are passed", function ()
      assert.is_table(eventable.object())
   end)

   it("adds methods to an existing table", function ()
      local t = {}
      assert.is_equal(t, eventable.object(t))
      assert.is_function(t.fire)
      assert.is_function(t.hook)
      assert.is_function(t.unhook)
   end)

   it("passes the table as first argument when firing events", function ()
      local t = assert(eventable.object())
      local h = spy.new(function (o)
         assert.is_equal(t, o)
      end)
      t:hook("foo", h)
      t:fire("foo")
      assert.spy(h).was_called_with(t)
   end)

   it("allows chaining :hook() and :unhook() calls", function ()
      local t = assert(eventable.object())
      local h = function () end
      assert.is_equal(t, t:hook("foo", h))
      assert.is_equal(t, t:unhook("foo", h))
      assert.is_equal(t, t:hook("foo", h):unhook("foo", h))
   end)
end)
