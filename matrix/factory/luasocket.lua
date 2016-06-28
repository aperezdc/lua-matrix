#! /usr/bin/env lua
--
-- luasocket.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local urlescape    = require "socket.url" .escape
local stringsource = require "ltn12"      .source.string
local tablesink    = require "ltn12"      .sink.table

local request_https = function (...)
   request_https = require "ssl.https" .request
   return request_https(...)
end

local request_http = function (...)
   request_http = require "socket.http" .request
   return request_http(...)
end

local function make_request(t)
   if t.url:sub(1, #"https://") == "https://" then
      return request_https(t)
   else
      return request_http(t)
   end
end

local function dict_to_query(d)
   local r, i = {}, 0
   for name, value in pairs(d) do
      i = i + 1
      r[i] = urlescape(name) .. "=" .. urlescape(value)
   end
   return table.concat(r, "&", 1, i)
end

local httpclient = {
   quote   = require "socket.url" .escape,
   unquote = require "socket.url" .unescape,
}
httpclient.__name  = "matrix.factory.luasocket"
httpclient.__index = httpclient

function httpclient:__tostring()
   return self.__name
end

function httpclient:request(log, method, url, query_args, body, headers)
   do
      local qs = dict_to_query(query_args)
      if #qs > 0 then
         url = url .. "?" .. qs
      end
   end

   log(">~> %s %s", method, url)
   log(">>> %s", body)

   local source
   if body and #body > 0 then
      headers["content-length"] = #body
      source = stringsource(body)
   end
   local result = {}
   local r, c, h = make_request {
      url     = url,
      method  = method,
      headers = headers,
      source  = source,
      sink    = tablesink(result),
   }
   local response = table.concat(result)

   log("<~< %d", c)
   log("<<< %s", response)

   return c, h, response
end

return function ()
   return setmetatable({}, httpclient)
end
