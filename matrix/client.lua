#! /usr/bin/env lua
--
-- client.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local User = {}
User.__name  = "matrix.user"
User.__index = User

setmetatable(User, { __call = function (self, client, user_id)
   return setmetatable({ user_id = user_id, _client = client }, User)
end })

function User:__tostring()
   return self.__name .. "{" .. self.user_id .. "}"
end

function User:get_display_name()
   return self._client._api:get_display_name(self.user_id)
end

function User:set_display_name(display_name)
   return self._client._api:set_display_name(self.user_id, display_name)
end

function User:get_avatar_url()
   local mxc_url = self._client._api:get_avatar_url(self.user_id)
   return self._client._api:get_download_url(mxc_url)
end

function User:set_avatar_url(avatar_url)
   return self._client._api:set_avatar_url(self.user_id, avatar_url)
end


local Room = {}
Room.__name  = "matrix.room"
Room.__index = Room

setmetatable(Room, { __call = function (self, client, room_id)
   return setmetatable({
      room_id = room_id,
      aliases = {},
      events  = {},
      _client = client,
   }, Room)
end })

function Room:__tostring()
   return self.__name .. "{" .. self.room_id .. "}"
end

function Room:send_text(text)
   return self._client._api:send_message(self.room_id, text)
end

function Room:send_emote(text)
   return self._client._api:send_emote(self.room_id, text)
end

function Room:send_notice(text)
   return self._client._api:send_notice(self.room_id, text)
end

function Room:invite_user(user_id)
   -- XXX: Do we really want to pcall(), or should error propagate?
   return pcall(self._client._api.invite_user,
      self._client._api, self.room_id, user_id)
end

function Room:kick_user(user_id)
   -- XXX: Do we really want to pcall(), or should error propagate?
   return pcall(self._client._api.kick_user,
      self._client._api, self.room_id, user_id)
end

function Room:ban_user(user_id)
   -- XXX: Do we really want to pcall(), or should error propagate?
   return pcall(self._client._api.ban_user,
      self._client._api, self.room_id, user_id)
end

function Room:leave()
   -- XXX: Maybe this should use pcall()?
   self._client._api:leave_room(self.room_id)
   self._client.rooms[self.room_id] = nil
end


local Client = {}
Client.__name  = "matrix.client"
Client.__index = Client

setmetatable(Client, { __call = function (self, base_url, token, http_factory)
   local c = setmetatable({
      rooms = {},  -- Indexed by room_id
      _api = require("matrix.api")(base_url, token, http_factory),
   }, Client)
   -- Do an initial sync if a token was provided on construction.
   if token then
      c:_sync()
   end
   return c
end })

function Client:__tostring()
   return self.__name .. "{" .. self._api.base_url .. "}"
end

function Client:register_with_password(username, password, limit)
   return self:_logged_in(self._api:register("m.login.password",
      { user = username, password = password }), limit)
end

function Client:login_with_password(username, password, limit)
   return self:_logged_in(self._api:login("m.login.password",
      { user = username, password = password }), limit)
end

function Client:_logged_in(response, limit)
   self.user_id    = response.user_id
   self.homeserver = response.home_server
   self.token      = response.access_token
   self._api.token = response.access_token
   self:_sync(limit)
   return self.token
end

function Client:logout()
   return self._api:logout()
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

function Client:join_room(room_id_or_alias)
   local response = self._api:join_room(room_id_or_alias)
   return self:_make_room(response.room_id or room_id_or_alias)
end

function Client:_make_room(room_id)
   local room = Room(self, room_id)
   self.rooms[room_id] = room
   return room
end

function Client:_sync(limit)
   local response = self._api:initial_sync(limit)
   self._end = response._end
   for _, room in ipairs(response.rooms) do
      local current_room = self:_make_room(room.room_id)
      for _, chunk in ipairs(room.messages.chunk) do
         table.insert(current_room.events, chunk)
      end
      for _, state_event in ipairs(room.state) do
         self:_process_state_event(state_event, current_room)
      end
   end
end

function Client:_process_state_event(event, room)
   local event_type = event.type
   if not event_type then
      return  -- Ignore event
   end
   if event_type == "m.room.name" then
      room.name = event.content.name
   elseif event_type == "m.room.topic" then
      room.topic = event.content.topic
   elseif event_type == "m.room.aliases" then
      room.aliases = event.content.aliases
   end
end


return { room = Room, user = User, client = Client }
