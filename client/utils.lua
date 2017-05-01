local socket = require "clientsocket"

local function writeline(fd, text)
  socket.send(fd, text .. "\n")
end

local function unpack_line(text)
  local from = text:find("\n", 1, true)
  if from then
    return text:sub(1, from-1), text:sub(from+1)
  end
  return nil, text
end

local function unpack_f(fd, f)
  local last = ""
  local function try_recv(fd, last)
    local result
    result, last = f(last)
    if result then
      return result, last
    end
    local r = socket.recv(fd)
    if not r then
      return nil, last
    end
    if r == "" then
      error "Server closed"
    end
    return f(last .. r)
  end

  return function()
    while true do
      local result
      result, last = try_recv(fd, last)
      if result then
        return result
      end
      socket.usleep(100)
    end
  end
end

local function send_request(fd, v)
  socket.send(fd, string.pack(">s2", v))
  return v
end

local function unpack_package(text)
  local size = #text
  if size < 2 then
    return nil, text
  end
  local s = string.unpack('>I2', text)
  if size < s + 2 then
    return nil, text
  end

  return text:sub(3,2+s), text:sub(3+s)
end

return {
  send_request   = send_request,
  writeline      = writeline,
  unpack_f       = unpack_f,
  unpack_line    = unpack_line,
  unpack_package = unpack_package,
}
