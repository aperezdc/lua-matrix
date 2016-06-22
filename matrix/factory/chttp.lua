#! /usr/bin/env lua
--
-- chttp.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local request = require "http.request"
local headers = require "http.headers"
local util    = require "http.util"

local encodeURI, decodeURI = util.encodeURI, util.decodeURI
local dict_to_query = util.dict_to_query


local CqHttpClient = {
   quote   = function (self, text) return encodeURI(text) end,
   unquote = function (self, text) return decodeURI(text) end,
}
CqHttpClient.__index = CqHttpClient


local function headers_to_dict(h)
   local headers = {}
   for name, value in pairs(h) do
      if name:sub(1, 1) ~= ":" then
         headers[name] = value
      end
   end
   return headers
end


function CqHttpClient:request(log, method, url, query_args, body, headers)
   do
      local qs = dict_to_query(query_args)
      if #qs > 0 then
         url = url .. "?" .. qs
      end
   end

   log(">~> %s %s", method, url)
   log(">>> %s", body)

   local req = request.new_from_uri(url)
   for name, value in pairs(headers) do
      req.headers:append(name, value)
   end
   req.headers:upsert(":method", method)
   if body then
      req:set_body(body)
   end
   local h, s = req:go()
   if not h then
      log("<!< error: %s", s)
      return 0, {}, s
   end
   local status = tonumber(h:get(":status"))
   local response = s:get_body_as_string()

   log("<~< %d", status)
   log("<<< %s", response)

   return status, headers_to_dict(h), response
end

return function ()
   return setmetatable({}, CqHttpClient)
end
