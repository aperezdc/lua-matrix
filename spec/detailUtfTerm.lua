#! /usr/bin/env lua
--
-- detailUtfTerm.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local colors = require 'term.colors'

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.utfTerminal' (options)

  handler.fileStart = function(element)
    io.write("\n" .. colors.cyan(handler.getFullName(element)) .. ':')
  end

  handler.testStart = function(element, parent, status, debug)
    local name = handler.getFullName(element)
    local len = #name
    if len > 72 then
       name = name:sub(1, 72) .. colors.white(" […] ")
       io.write("\n " .. name)
    else
       len = len + 2
       io.write('\n ' .. name .. " ")
       for i = 1, 78 - len - 1 do
          io.write(colors.white('·'))
       end
       io.write(" ")
    end
    io.flush()
  end

  busted.subscribe({ 'file', 'start' }, handler.fileStart)
  busted.subscribe({ 'test', 'start' }, handler.testStart)

  return handler
end
