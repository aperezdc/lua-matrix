#! /usr/bin/env lua
--
-- api-send-message.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

if #arg ~= 4 then
   io.stderr:write(string.format("Usage: %s <homeserver-URL> <username> <password> <room>\n", arg[0]))
   os.exit(1)
end

local api = require "matrix" .api(arg[1])
local response = api:login("m.login.password", { user = arg[2], password = arg[3] })
api.token = response.access_token
api:send_message(arg[4], io.read("*a"))
api:logout()
