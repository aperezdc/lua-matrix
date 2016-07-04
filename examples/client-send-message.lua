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

-- Passing "true" as last parameter skips the initial sync, which can be slow
client:login_with_password(arg[2], arg[3], true)

local room = client:join_room(arg[4])
room:send_text(io.read("*a"))

client:logout()
