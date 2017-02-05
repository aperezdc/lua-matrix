#! /usr/bin/env lua
--
-- client.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local json      = require "cjson"
local API       = require "matrix.api"
local eventable = require "matrix.eventable"

local function noprintf(...) end
local function eprintf(fmt, ...)
   io.stderr:write("[client] ")
   io.stderr:write(fmt:format(...))
   io.stderr:write("\n")
   io.stderr:flush()
end

local function get_debug_log_function()
   local env_value = os.getenv("MATRIX_CLIENT_DEBUG_LOG")
   if env_value and #env_value > 0 and env_value ~= "0" then
      return eprintf
   else
      return noprintf
   end
end


local function sanitize(text)
   return (text:gsub("[^0-9a-zA-Z_]", "__"))
end

local function sorted_string_list_eq(a, b)
   if #a == #b then
      for i = 1, #a do
         if a[i] ~= b[i] then
            return false
         end
      end
      return true
   else
      return false
   end
end

local function set_simple_property(self, name, new_value)
   local old_value = self[name]
   if old_value == new_value then
      self:_log(".%s: %s (unchanged)", name, old_value)
      return false
   else
      self[name] = new_value
      self:_log(".%s: %s -> %s", name, old_value, new_value)
      self:fire("property-changed", name, old_value)
      return true
   end
end

local function set_string_list_property(self, name, new_value)
   local old_value = self[name]
   table.sort(old_value)
   table.sort(new_value)
   if sorted_string_list_eq(old_value, new_value) then
      self:_log(".%s: [%s] (unchanged)", name, table.concat(old_value, ", "))
      return false
   else
      self[name] = new_value
      self:fire("property-changed", name, old_value, new_value)
      self:_log(".%s: [%s] -> [%s]", name, table.concat(old_value, ", "),
                                           table.concat(new_value, ", "))
      return true
   end
end


local User = {}
User.__name  = "matrix.user"
User.__index = User

setmetatable(User, { __call = function (self, client, user_id)
   return eventable.object(setmetatable({
      user_id = user_id,
      client  = client,
   }, User))
end })

function User:__tostring()
   return self.__name .. "{" .. self.user_id .. "}"
end

function User:__eq(other)
   return getmetatable(other) == User and self.user_id == other.user_id
end

function User:_log(fmt, ...)
   self.client._log("{%s} " .. fmt, self.user_id, ...)
end

function User:update_display_name(value)
   if value and value ~= self.display_name then
      self.client._api:set_display_name(self.user_id, value)
   elseif not value then
      value = self.client._api:get_display_name(self.user_id)
   end
   return set_simple_property(self, "display_name", value)
end

function User:update_avatar_url(value)
   if value and value ~= self.avatar_url then
      self.client._api:set_avatar_url(self.user_id, value)
   elseif not value then
      value = self.client._api:get_avatar_url(self.user_id)
   end
   return set_simple_property(self, "avatar_url", value)
end


local Room = {}
Room.__name  = "matrix.room"
Room.__index = Room

setmetatable(Room, { __call = function (self, client, room_id)
   return eventable.object(setmetatable({
      room_id = room_id,
      aliases = {},
      members = {},
      invited = {},
      client  = client,
   }, Room))
end })

function Room:__tostring()
   return self.__name .. "{" .. self.room_id .. "}"
end

function Room:__eq(other)
   return getmetatable(other) == Room and self.room_id == other.room_id
end

function Room:_log(fmt, ...)
   self.client._log("{%s} " .. fmt, self.room_id, ...)
end

function Room:send_text(text)
   -- XXX: How does error handling work here?
   return self.client._api:send_message(self.room_id, text).event_id
end

function Room:send_emote(text)
   -- XXX: How does error handling work here?
   return self.client._api:send_emote(self.room_id, text).event_id
end

function Room:send_notice(text)
   -- XXX: How does error handling work here?
   return self.client._api:send_notice(self.room_id, text).event_id
end

function Room:invite_user(user_id)
   -- XXX: Do we really want to pcall(), or should error propagate?
   return pcall(self.client._api.invite_user,
      self.client._api, self.room_id, user_id)
end

function Room:kick_user(user_id)
   -- XXX: Do we really want to pcall(), or should error propagate?
   return pcall(self.client._api.kick_user,
      self.client._api, self.room_id, user_id)
end

function Room:ban_user(user_id)
   -- XXX: Do we really want to pcall(), or should error propagate?
   return pcall(self.client._api.ban_user,
      self.client._api, self.room_id, user_id)
end

function Room:leave()
   -- XXX: Maybe this should use pcall()?
   self:fire("leave")
   self.client._api:leave_room(self.room_id)
   self.client.rooms[self.room_id] = nil
   self.client:fire("left", self)
end

function Room:update_room_name()
   local response = self.client._api:get_room_name(self.room_id)
   if response.name and response.name ~= self.name then
      return set_simple_property(self, "name", response.name)
   end
   return false
end

function Room:update_room_topic()
   local response = self.client._api:get_room_topic(self.room_id)
   if response and response.topic ~= self.topic then
      return set_simple_property(self, "topic", response.topic)
   end
   return false
end

function Room:update_aliases()
   local response = self.client._api:get_room_state(self.room_id)
   for _, chunk in ipairs(response) do
      if chunk.content and chunk.content.aliases then
         return set_string_list_property(self, "aliases", chunk.content.aliases)
      end
   end
   return false
end

function Room:get_alias_or_id()
   if self.canonical_alias then
      return self.canonical_alias
   elseif #self.aliases == 1 then
      return self.aliases[1]
   elseif #self.aliases > 1 then
      local shorter_index = 1
      for index, alias in ipairs(self.aliases) do
         if #alias < #self.aliases[shorter_index] then
            shorter_index = index
         end
      end
      return self.aliases[shorter_index]
   else
      return self.room_id
   end
end

local make_unimplemented_handler = function (self, event)
   local env_value = os.getenv("MATRIX_CLIENT_LOG_UNHANDLED_EVENTS")
   if env_value and #env_value > 0 and env_value ~= "0" then
      local function handler(self, event)
         self:_log("unhandled '%s' event: %s", event.type, json.encode(event))
      end
      make_unimplemented_handler = function (self, event)
         return handler
      end
   else
      local function handler(self, event) end
      make_unimplemented_handler = function (self, event)
         self:_log("no handler for '%s' events (this warning is shown only once)", event.type)
         return handler
      end
   end
   return make_unimplemented_handler(self, event)
end

function Room:_push_events(events)
   self:_log("processing %d timeline events", #events)
   for _, event in ipairs(events) do
      local handler_name = "_push_event__" .. sanitize(event.type)
      local handler = self[handler_name]
      if not handler then
         handler = make_unimplemented_handler(self, event)
         self[handler_name] = handler
      end
      handler(self, event)
   end
end

function Room:_push_event__m__room__create(event)
   set_simple_property(self, "creator", event.content.creator)
end

function Room:_push_event__m__room__aliases(event)
   set_string_list_property(self, "aliases", event.content.aliases)
end

function Room:_push_event__m__room__canonical_alias(event)
   set_simple_property(self, "canonical_alias", event.content.alias)
end

function Room:_push_event__m__room__name(event)
   set_simple_property(self, "name", event.content.name)
end

function Room:_push_event__m__room__join_rules(event)
   set_simple_property(self, "join_rule", event.content.join_rule)
end

function Room:_push_event__m__room__history_visibility(event)
   set_simple_property(self, "history_visibility", event.content.history_visibility)
end

function Room:_push_event__m__room__member(event)
   if event.content.membership == "join" then
      local user = self.client:_make_user(event.state_key,
         event.content.displayname, event.content.avatar_url)
      self.members[user.user_id] = user
      self:fire("member-joined", user)
   elseif event.content.membership == "invite" then
      local user = self.client:_make_user(event.state_key,
         event.content.displayname, event.content.avatar_url)
      -- FIXME: Setting property from outside the User object itself.
      set_simple_property(user, "invited_by", event.sender)
      self.invited[user.user_id] = user
      self:fire("member-invited", user)
   elseif event.content.membership == "leave" then
      local user = self.members[event.state_key] or self.invited[event.state_key]
      if user then
         if user.invited_by then
            self.invited[user.user_id] = nil
         else
            self.members[user.user_id] = nil
         end
         self:fire("member-left", user)
         -- TODO: Do we remove the user from self.client.presence??
      end
   else
      error("Unhandled event: " .. json.encode(event))
   end
end

function Room:_push_event__m__room__message(event)
   self:fire("message", event.sender, event.content, event)
end


local Client = {}
Client.__name  = "matrix.client"
Client.__index = Client

setmetatable(Client, { __call = function (self, base_url, token, http_client)
   return eventable.object(setmetatable({
      presence = {},  -- Indexed by user_id
      rooms = {},     -- Indexed by room_id
      _log = get_debug_log_function(),
      _api = API(base_url, token, http_client),
   }, Client))
end })

function Client:__tostring()
   return self.__name .. "{" .. self._api.base_url .. "}"
end

function Client:register_with_password(username, password)
   return self:_logged_in(self._api:register("m.login.password",
      { user = username, password = password }))
end

function Client:login_with_password(username, password)
   return self:_logged_in(self._api:login("m.login.password",
      { user = username, password = password }))
end

function Client:_logged_in(response)
   self._log("logged-in: %s", response.user_id)
   self.user_id    = response.user_id
   self.homeserver = response.home_server
   self.token      = response.access_token
   self._api.token = response.access_token
   self:fire("logged-in")
   return self.token
end

function Client:logout()
   local ret = self._api:logout()
   self:fire("logged-out")
   return ret
end

function Client:get_user()
   return self.user_id and User(self, self.user_id) or nil
end

function Client:create_room(alias, public, invite)
   local response = self._api:create_room {
      alias  = alias,
      public = public,
      invite = invite,
   }
   return self:_make_room(response.room_id)
end

function Client:join_room(room)
   if type(room) == "string" then
      local response = self._api:join_room(room)
   elseif type(room) == "table" and getmetatable(room) == Room then
      local response = self._api:join_room(room.room_id)
   else
      error("argument #1 must be a string or a room object")
   end
   return self:_make_room(response.room_id)
end

function Client:_make_room(room_id)
   local room = self.rooms[room_id]
   if not room then
      room = Room(self, room_id)
      self.rooms[room_id] = room
      self:fire("joined", room)
   end
   return room
end

function Client:find_room(room_id_or_alias)
   for room_id, room in pairs(self.rooms) do
      if room_id_or_alias == room_id or
         room_id_or_alias == room.canonical_alias
      then
         return room
      end
      for _, alias in ipairs(room.aliases) do
         if room_id_or_alias == alias then
            return room
         end
      end
   end
end

function Client:_make_user(user_id, display_name, avatar_url)
   local user = self.presence[user_id]
   if not user then
      user = User(self, user_id)
      self.presence[user_id] = user
   end
   -- Set properties directly to avoid issues set_* API calls.
   set_simple_property(user, "display_name", display_name)
   set_simple_property(user, "avatar_url", avatar_url)
   return user
end

local function xpcall_add_traceback(errmsg)
   local tb = debug.traceback(nil, nil, 2)
   if errmsg then
      return errmsg .. "\n" .. tb
   else
      return tb
   end
end

function Client:_sync(options)
   if not options then
      options = {}
   end
   if not options.since then
      options.since = self._sync_next_batch
   end
   self._log("sync: Requesting with next_batch = %s", options.since)

   local response = self._api:sync(options)
   self._sync_next_batch = response.next_batch

   for _, kind in ipairs { "join", "invite", "leave" } do
      local handle = self["_sync_handle_room__" .. kind]
      for room_id, room_data in pairs(response.rooms[kind]) do
         self._log("sync: %s %s", kind, room_id)
         -- XXX: Maybe this is abusing pcall() too much to allow handler
         --      code to bail and continue with the next room instead of
         --      completely failing to sync. Dunno.
         local ok, err = xpcall(handle, xpcall_add_traceback, self, room_id, room_data)
         if not ok then
            self._log("sync: Error handling '%s' event for room %s:\n%s", kind, room_id, err)
            self._log("sync: Event payload: %s", json.encode(room_data))
         end
      end
   end
end

local function return_false()
   return false
end

function Client:sync(stop, timeout)
   if not stop then
      stop = return_false
   end
   repeat
      self:_sync { timeout = timeout or 15000 }
   until stop(self)
end

function Client:_sync_handle_room__join(room_id, data)
   local room = self:_make_room(room_id)
   room:_push_events(data.timeline.events)
end

function Client:_sync_handle_room__invite(room_id, data)
   local room = Room(self, room_id)
   room:_push_events(data.invite_state.events)
   self:fire("invite", room)
end

function Client:_sync_handle_room__leave(room_id, data)
   local room = assert(self.rooms[room_id], "No such room")
   room:_push_timeline_events(data.timeline)
   room:leave()
end


return { room = Room, user = User, client = Client, api = API }
