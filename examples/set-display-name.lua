#! /usr/bin/env lua
--
-- get-user-info.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

if #arg ~= 4 then
   io.stderr:write(string.format("Usage: %s <homeserver-URL> <username> <password> <displayname>\n", arg[0]))
   os.exit(1)
end

local api = require "matrix" .api(arg[1])

-- Login and configure the access token used for further API requests
local response = api:login("m.login.password", { user = arg[2], password = arg[3] })
api.token = response.access_token

-- Set the display name
api:set_display_name(response.user_id, arg[4])
api:logout()
