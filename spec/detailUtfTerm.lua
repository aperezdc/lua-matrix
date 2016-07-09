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
    io.write('\n   ' .. handler.getFullName(element) .. '\r ')
    io.flush()
  end

  busted.subscribe({ 'file', 'start' }, handler.fileStart)
  busted.subscribe({ 'test', 'start' }, handler.testStart)

  return handler
end
