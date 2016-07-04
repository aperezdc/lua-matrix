#! /usr/bin/env lua
--
-- send-message.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

if #arg ~= 4 then
   io.stderr:write(string.format("Usage: %s <homeserver-URL> <username> <password> <room>\n", arg[0]))
   os.exit(1)
end

local client = require "matrix" .client(arg[1])
client:login_with_password(arg[2], arg[3])

-- FIXME: This does not resolve room aliases, it works only with room IDs
local room = client.rooms[arg[4]]
if not room then
   room = client:join_room(arg[4])
end

room:send_text(io.read("*a"))
client:logout()
