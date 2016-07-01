#! /usr/bin/env lua
--
-- api.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local json = require "cjson"

local function noprintf(...) end
local function eprintf(fmt, ...)
   io.stderr:write("[api] ")
   io.stderr:write(fmt:format(...))
   io.stderr:write("\n")
   io.stderr:flush()
end

local function get_debug_log_function()
   local env_value = os.getenv("MATRIX_API_DEBUG_LOG")
   if env_value and #env_value > 0 and env_value ~= "0" then
      return eprintf
   else
      return noprintf
   end
end

local get_http_client = function (http_client)
   -- The environment variable has precedence, as it is used to aid debugging.
   do
      local env_value = os.getenv("MATRIX_API_HTTP_CLIENT")
      if env_value and #env_value > 0 then
         http_client = env_value
      end
   end
   -- Try to import supplied HTTP client libraries, in order of preference.
   local tries = http_client and { http_client } or { "chttp", "luasocket" }
   local errors = {}
   for i, http_client in ipairs(tries) do
      local ok, client = pcall(require, "matrix.httpclient." .. http_client)
      if ok then
         get_http_client = function () return client end
         return get_http_client()
      end
      errors[i] = client
   end
   local errmsg = { "Could not load any HTTP client library:" }
   for i, name in pairs(tries) do
      errmsg[#errmsg + 1] = "--- Loading '" .. name .. "'"
      errmsg[#errmsg + 1] = errors[i]
   end
   error(table.concat(errmsg, "\n"))
end


local API = {}
API.__name  = "matrix.api"
API.__index = API

setmetatable(API, { __call = function (self, base_url, token, http_client)
   return setmetatable({
      base_url = base_url,
      token = token,
      txn_id = 0,
      api_path = "/_matrix/client/r0",  -- TODO: De-hardcode
      _log = get_debug_log_function(),
      _http = get_http_client(http_client)(),
   }, API)
end })

function API:__tostring()
   return self.__name .. "{" .. self.base_url .. "}"
end

----
-- | Option   | Type    | Default Value |
-- |:=========|:========|===============|
-- | filter   | string  | nil           |
-- | since    | string  | nil           |
-- | full     | boolean | false         |
-- | online   | boolean | true          |
-- | timeout  | number  | nil           |
----
function API:sync(options)
   local params
   if options then
      params = {
         filter = options.filter,
         ince = options.since,
         full_state = options.full or false,
         set_presence = online and nil or "offline",
         timeout = options.timeout,
      }
   end
   return self:_send("GET", "/sync", params)
end

function API:register(login_type, params)
   return self:_send_with_params("POST", "/register", nil,
      { type = login_type }, params)
end

function API:login(login_type, params)
   return self:_send_with_params("POST", "/login", nil,
      { type = login_type }, params)
end

function API:logout()
   return self:_send("POST", "/logout")
end

function API:refresh_token(refresh_token)
   return self:_send("POST", "/tokenrefresh", nil, { refresh_token = refresh_token })
end

function API:set_password(new_password, params)
   return self:_send_with_params("POST", "/account/password",
      { new_password = new_password }, params)
end

function API:get_3pids()
   local data = self:_send("GET", "/account/3pid")
   return data.threepids
end

function API:set_3pids(threepids, bind)
   return self:_send("POST", "/account/3pid", nil,
      { three_pid_creds = threepids, bind = (bind and true or false) })
end

----
-- | Option    | Type     | Default Value |
-- |:==========|:=========|===============|
-- | alias     | string   | nil           |
-- | public    | boolean  | false         |
-- | invite    | {string} | {}            |
----
function API:create_room(options)
   local params = {
      visibility = options.public and "public" or "private",
      room_alias_name = options.alias,
      invite = options.invite,
   }
   return self:_send("POST", "/createRoom", nil, params)
end

function API:join_room(room_id_or_alias)
   return self:_send("POST", "/join/" .. self._http.quote(room_id_or_alias))
end

function API:event_stream(from_token, timeout)
   return self:_send("GET", "/events", { from = from_token, timeout = timeout or 30000 })
end

function API:send_state_event(room_id, event_type, content, state_key)
   local path = "/rooms/" .. self._http.quote(room_id) ..
                "/state/" .. self._http.quote(event_type)
   if state_key then
      path = path .. "/" .. self._http.quote(state_key)
   end
   return self:_send("PUT", path, nil, content)
end

function API:send_message_event(room_id, event_type, content, txn_id)
   if not txn_id then
      txn_id = self.txn_id
      self.txn_id = self.txn_id + 1
   end
   local path = "/rooms/" .. self._http.quote(room_id) .. "/send/" ..
                self._http.quote(event_type) .. "/" ..
                self._http.quote(tostring(txn_id))
   return self:_send("PUT", path, nil, content)
end

function API:send_content(room_id, item_url, item_name, msg_type, extra_info)
   return self:send_message_event(room_id, "m.room.message",
      { url = item_url, msgtype = msg_type, body = item_name, info = extra_info })
end

function API:send_message(room_id, text_content, msg_type)
   return self:send_message_event(room_id, "m.room.message",
      self:get_text_body(text_content, msg_type or "m.text"))
end

function API:send_emote(room_id, text_content)
   return self:send_message_event(room_id, "m.room.message",
      self:get_emote_body(text_content))
end

function API:send_notice(room_id, text_content)
   return self:send_message_event(room_id, "m.room.message",
      { msgtype = "m.notice", body = text_content })
end

function API:get_room_name(room_id)
   return self:_send("GET", "/rooms/" .. self._http.quote(room_id) .. "/state/m.room.name")
end

function API:get_room_topic(room_id)
   return self:_send("GET", "/rooms/" .. self._http.quote(room_id) .. "/state/m.room.topic")
end

function API:leave_room(room_id)
   return self:_send("POST", "/rooms/" .. self._http.quote(room_id) .. "/leave")
end

function API:invite_user(room_id, user_id)
   return self:_send("POST", "/rooms/" .. self._http.quote(room_id) .. "/invite", nil,
      { user_id = user_id })
end

function API:kick_user(room_id, user_id, reason)
   return self:set_membership(room_id, user_id, "leave", reason)
end

function API:set_membership(room_id, user_id, membership, reason)
   local path = "/rooms/" .. self._http.quote(room_id) ..
                "/state/m.room.member/" .. self._http.quote(user_id)
   return self:_send("PUT", path, nil, { membership = membership, reason = reason or "" })
end

function API:ban_user(room_id, user_id, reason)
   return self:_send("POST", "/rooms/" .. self._http.quote(room_id) .. "/ban", nil,
      { user_id = user_id, reason = reason or "" })
end

function API:get_room_state(room_id)
   return self:_send("GET", "/rooms/" .. self._http.quote(room_id) .. "/state")
end

function API:get_text_body(text, msg_type)
   return { msgtype = msg_type or "m.text", body = text }
end

function API:get_emote_body(text)
   return { msgtype = "m.emote", body = text }
end

function API:media_upload(content, content_type)
   -- TODO: De-harcode media API path
   return self:_send("POST", "", nil, content,
      { ["content-type"] = content_type },
      "/_matrix/media/r0/upload")
end

function API:get_display_name(user_id)
   local data = self:_send("GET", "/profile/" .. self._http.quote(user_id) .. "/displayname")
   return data.displayname
end

function API:set_display_name(user_id, display_name)
   return self:_send("PUT", "/profile/" .. self._http.quote(user_id) .. "/displayname",
      nil, { displayname = display_name })
end

function API:get_avatar_url(user_id)
   local data = self:_send("GET", "/profile/" .. self._http.quote(user_id) .. "/avatar_url")
   return data.avatar_url
end

function API:set_avatar_url(user_id, avatar_url)
   return self:_send("PUT", "/profile/" .. self._http.quote(user_id) .. "/avatar_url",
      nil, { avatar_url = avatar_url })
end

function API:get_download_url(mxc_url)
   if mxc_url:sub(1, #"mxc://") == "mxc://" then
      -- TODO: De-hardcode API version
      return self.base_url .. "/_matrix/media/r0/download/" .. mxc_url:sub(7)
   end
   error("no mxc: scheme in URL: " .. mxc_url)
end

function API:_send_with_params(method, path, query_args, params, extra_params)
   for name, value in pairs(extra_params) do
      params[name] = value
   end
   return self:_send(method, path, query_args, params)
end

function API:_send(method, path, query_args, body, headers, api_path)
   -- Ensure that there is a Content-Type header.
   if not headers then
      headers = {}
   end
   if not headers["content-type"] then
      headers["content-type"] = "application/json"
   end

   -- Encode the request body, if necessary.
   if headers["content-type"] == "application/json" then
      body = body and json.encode(body) or "{}"
   elseif not body then
      body = ""
   end

   -- Copy the parameters, adding the access token.
   local params = { access_token = self.token }
   if query_args then
      for name, value in pairs(query_args) do
         params[name] = tostring(value)
      end
   end

   -- Call the HTTP library.
   self._log("-!- HTTP client: %s", self._http)
   local code, headers, body = self._http:request(self._log, method:upper(),
      self.base_url .. (api_path or self.api_path) .. path, params, body, headers)
   if code == 200 then
      if headers["content-type"] == "application/json" then
         body = json.decode(body)
      end
      return body
   else
      return error("HTTP " .. tostring(code) .. " - " .. body)
   end
end


return API
