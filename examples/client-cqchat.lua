#! /usr/bin/env lua
--
-- client-cqchat.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
--
-- Distributed under terms of the MIT license.
--

local cqueues = require "cqueues"
local posix   = require "posix"
local bit     = require "bit32"
local matrix  = require "matrix"

local function xpcall_traceback(errmsg)
   local tb = debug.traceback(nil, nil, 2)
   return errmsg and (errmsg .. "\n" .. tb) or tb
end

--
-- Wraps the controlling terminal into an object which can be polled
-- with cqueues.poll() and uses O_NONBLOCK for input.
--
local tty = {
   file = (function ()
      local f = io.open(posix.ctermid(), "a+")
      local fd = posix.fileno(f)
      local flags = posix.fcntl(fd, posix.F_GETFL, 0)
      flags = bit.bor(flags, assert(posix.O_NONBLOCK))
      if posix.O_CLOEXEC then
         flags = bit.bor(flags, posix.O_CLOEXEC)
      else
         io.stderr:write("no O_CLOEXEC, the TTY file descriptor might leak")
         io.stderr:flush()
      end
      if posix.fcntl(fd, posix.F_SETFL, flags) ~= 0 then
         error("cannot set O_NONBLOCK/O_CLOEXEC: " .. posix.errno())
      end
      return f
   end)(),

   -- Functions expected by cqueues
   pollfd = function (self) return posix.fileno(self.file) end,
   events = function () return "r" end,   -- Read only
   timeout = function () return nil end,  -- Set in the call to cqueues.poll()

   -- Wrappers for tcsetattr/tcgetattr
   tcgetattr = function (self) return posix.tcgetattr(self:pollfd()) end,
   tcsetattr = function (self, ...) return posix.tcsetattr(self:pollfd(), ...) end,

   -- Obtain the terminal size using TIOCGWINSZ
   _size_width = false,
   _size_height = false,

   size = function (self, force)
      if force then
         self._size_width = false
         self._size_height = false
      end
      if self._size_width == false then
         local p = io.popen("tput cols", "r")
         self._size_width = p:read("*n")
         p:close()
      end
      if self._size_height == false then
         local p = io.popen("tput lines", "r")
         self._size_height = p:read("*n")
         p:close()
      end
      return self._size_width, self._size_height
   end,

   -- Saves terminal attributes, runs a function, and restores attributes
   -- even if the function raises an error.
   wrap = function (self, f, ...)
      local saved_attr = self:tcgetattr()
      local ok, err = xpcall(f, xpcall_traceback, self, ...)
      self:tcsetattr(posix.TCSANOW, saved_attr)
      if not ok then
         error("tty:wrap: Error in wrapped function:\n" .. err)
      end
      return self
   end
}

local command_pattern = "^%s*/(%a+)%s+(.*)$"

local function main(tty, client, username, password)
   do
      local a = tty:tcgetattr()
      a.cc[posix.VMIN] = 1
      a.cc[posix.VTIME] = 0
      a.lflag = bit.band(a.lflag, bit.bnot(bit.bor(posix.ECHO, posix.ICANON)))
      a.iflag = bit.band(a.iflag, bit.bnot(bit.bor(posix.IXON, posix.ISTRIP)))
      a.cflag = bit.band(a.cflag, bit.bnot(bit.bor(posix.CSIZE, posix.PARENB)))
      a.cflag = bit.bor(a.cflag, posix.CS8)
      a.oflag = bit.band(a.oflag, bit.bnot(posix.OPOST))
      if tty:tcsetattr(posix.TCSANOW, a) ~= 0 then
         error("tcsetattr: " .. posix.errno())
      end
   end

   local cq = cqueues.new()
   local ok, err, obj = cq:wrap(function ()
      client:login_with_password(username, password)

      local running = true
      local client_should_stop = function () return not running end
      local clientqueue = cq:wrap(function ()
         client:sync(client_should_stop)
      end)

      local current_room
      while running do
         local line = ""
         while true do
            io.stdout:write(string.format("\r[K[1;1m[%s][0;0m %s",
               current_room and current_room:get_alias_or_id() or "*",
               line))
            io.stdout:flush()

            local handle_tty = false
            cqueues.poll(tty, 0.05)

            local ch = tty.file:read(1)
            if ch then
               if ch == "\4" and #line == 0 then
                  print("\r[K")
                  cq:cancel()
                  return
               elseif ch == "\127" then
                  line = line:sub(1, -2)
               elseif ch == "\n" then
                  break
               else
                  line = line .. ch
               end
            end
         end

         local command, params = line:match(command_pattern)
         if command then
            if command == "room" then
               if client.rooms[params] then
                  current_room = client.rooms[params]
               else
                  print("\r[K[1;31m/!\\[0;0m No such room")
               end
            end
         else
            if current_room then
               current_room:send_text(line)
            else
               print("\r[K[1;31m/!\\[0;0m Choose a room using '/room <room_id>'")
            end
         end
      end
   end):loop()
   if not ok then
      error(err)
   end
end

local function print_room_message(room, sender, message, event)
   print(string.format("\rK[[37m%s[0m] <[36m%s[0m> %s", room.room_id, sender, message.body))
end

if #arg ~= 3 then
   io.stderr:write(string.format("Usage: %s <homeserver> <username> <password>\n", arg[0]))
   os.exit(1)
end

--
-- Force usage of "chttp", the cqueues-based HTTP client library
--
local client = matrix.client(arg[1], nil, "chttp")
   :hook("logged-in", function (client)
      print("\r[K[1;32m *[0;0m Logged in as " .. client.user_id)
   end)
   :hook("joined", function (client, room)
      room:update_aliases()
      local extra = ""
      if #room.aliases > 0 then
         extra = " (" .. table.concat(room.aliases, ", ") .. ")"
      end
      print("\r[K[1;32m *[0;0m Joined room " .. room.room_id .. extra)
      room:hook("message", print_room_message)
   end)
   :hook("left", function (client, room)
      print("\r[K[1;32m *[0;0m Left room " .. room.room_id)
   end)

tty:wrap(main, client, arg[2], arg[3])
