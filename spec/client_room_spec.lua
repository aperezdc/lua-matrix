#! /usr/bin/env lua
--
-- client_room_spec.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local matrix = require "matrix.client"

local A_ROOM_ID = "!crFlAIxFGhReTaXtra:local"

describe("matrix.room", function ()

   describe("__call metamethod", function ()
      it("instantiates", function ()
         local room = matrix.room({}, A_ROOM_ID)
         assert.is_not_equal(matrix.room, room)
         assert.is_equal(matrix.room, getmetatable(room))
      end)
      it("sets .room_id", function ()
         local dummy = {}
         local room = matrix.room(dummy, A_ROOM_ID)
         assert.is_equal(A_ROOM_ID, room.room_id)
      end)
      it("sets .client", function ()
         local dummy = {}
         local room = matrix.room(dummy, A_ROOM_ID)
         assert.is_equal(dummy, room.client)
      end)
      it("sets .aliases", function ()
         local room = matrix.room({}, A_ROOM_ID)
         assert.is_table(room.aliases)
      end)
      it("sets .members", function ()
         local room = matrix.room({}, A_ROOM_ID)
         assert.is_table(room.members)
      end)
   end)

   describe("__eq metamethod", function ()
      it("compares using .room_id", function ()
         local r1 = matrix.room({}, A_ROOM_ID)
         local r2 = matrix.room({}, A_ROOM_ID)
         assert.are_not_same(r1, r2)
         assert.are_equal(r1, r2)
         local r3 = matrix.room({}, "!someotherid:local")
         assert.are_not_same(r1, r3)
         assert.are_not_same(r2, r3)
         assert.are_not_equal(r1, r3)
         assert.are_not_equal(r2, r3)
      end)
   end)

end)
