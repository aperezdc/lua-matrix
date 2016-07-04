#! /usr/bin/env lua
--
-- echobot.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local function eprintf(fmt, ...)
   io.stderr:write(fmt:format(...))
   io.stderr:flush()
end

if #arg ~= 3 then
   eprintf("Usage: %s <homeserver> <username> <password>\n", arg[0])
   os.exit(1)
end

local client = require "matrix" .client(arg[1])
local running, start_ts = true, os.time() * 1000

client:hook("invite", function (client, room)
   -- When invited to a room, join it
   eprintf("Invited to room %s\n", room)
   client:join_room(room)
end):hook("logged-in", function (client)
   eprintf("Logged in successfully\n")
end):hook("logged-out", function (client)
   eprintf("Logged out... bye!\n")
end):hook("left", function (client, room)
   eprintf("Left room %s, active rooms:\n", room)
   for room_id, room in pairs(client.rooms) do
      assert(room_id == room.room_id)
      eprintf("  - %s\n", room)
   end
end):hook("joined", function (client, room)
   eprintf("Active rooms:\n")
   for room_id, room in pairs(client.rooms) do
      assert(room_id == room.room_id)
      eprintf("  - %s\n", room)
   end

   room:send_text("Type “!echobot go bananas” to make the bot exit")
   room:send_text("Type “!echobot leave the room” to make the bot leave the room")

   room:hook("message", function (room, sender, message, event)
      if event.origin_server_ts < start_ts then
         eprintf("%s: (Skipping message sent before bot startup)\n", room)
         return
      end
      if sender == room.client.user_id then
         eprintf("%s: (Skipping message sent by ourselves)\n", room)
         return
      end
      if message.msgtype ~= "m.text" then
         eprintf("%s: (Message of type %s ignored)\n", room, message.msgtype)
         return
      end

      eprintf("%s: <%s> %s\n", room, sender, message.body)

      if message.body == "!echobot leave the room" then
         room:send_text("(leaving the room as requested)")
         room:leave()
      elseif message.body == "!echobot go bananas" then
         for _, room in pairs(client.rooms) do
            room:send_text("(gracefully shutting down)")
         end
         running = false
      else
         -- Echo! That's what echobot does!
         room:send_text(message.body)
      end
   end)
end)

client:login_with_password(arg[2], arg[3])
client:sync(function () return not running end)
client:logout()
