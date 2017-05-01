--- hall 服务
-- 管理gate转发的socket消息
-- @module hall.socket

local skynet  = require "skynet"

local netpack      = require "netpack"
local socketdriver = require 'socketdriver'
local inspect = require 'inspect'

local crypt   = require 'crypt'
local b64decode = crypt.base64decode

local assert = assert

return function (data)

local info         = data.info
local connection   = data.connection
local user_login   = data.user_login

local handshake = {} -- {fd = addr} 握手的用户连接

local SOCKET = {}

--- 如果重连次数超出限制，禁止接入
-- @within SOCKET
function SOCKET.open(fd, addr)
  skynet.error('KEY POINT', 'hall: client connect gate:', fd, addr)
  handshake[fd] = addr
  skynet.call(info.gate, "lua", "accept", fd)
end

-- atomic, no yield
local function do_auth(fd, message, addr)
  local uin_server_subid, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")
  local uin = b64decode(string.match(uin_server_subid, "([^@]*)@*"))
  uin = tonumber(uin)
  local u = user_login[uin]
  if u == nil then
    return "404 User Not Found"
  end
  local idx = assert(tonumber(index))
  hmac = b64decode(hmac)

  skynet.error('KEY POINT', 'idx: ', idx, u.conn_idx)

  if idx <= u.conn_idx then
    return "403 Index Expired"
  end

  local text = string.format("%s:%s", uin_server_subid, index)
  local v = crypt.hmac_hash(u.secret, text)
  if v ~= hmac then
    return "401 Unauthorized"
  end

  --优先断掉以前的连接，节省服务器资源
  skynet.call(info.gate, "lua", "kick", u.fd)

  u.conn_idx = idx
  u.fd = fd
  u.ip = addr
  connection[fd] = u
end

local function close_connection(fd)
  handshake[fd] = nil
  local u = connection[fd]
  if u then
    connection[fd] = nil
    u.fd = nil
    skynet.send(u.agent, "lua", "leave")
    skynet.call(info.gate, "lua", "kick", fd)
  end
end

--- clientsocket 消息，处理认证 获取游戏服列表 公告等工作
-- @within SOCKET
function SOCKET.data(fd, msg)
  local socket_addr = handshake[fd]
  if socket_addr then
    handshake[fd] = nil
    local ok, result = pcall(do_auth, fd, msg, socket_addr)
    --if not ok then result = '400 Bad Request' end
    if not ok then result = "400 Bad Request" end
    local close = result ~= nil
    if result == nil then result = "200 OK" end

    skynet.error('KEY POINT', 'client handshake result :', fd, result, #result)

    socketdriver.send(fd, netpack.pack(result))
    if close then
      skynet.call(info.gate, 'lua', 'kick', fd)
    else
      local u = connection[fd]
      skynet.call(u.agent, 'lua', 'enter', {
        client_fd = fd,
        gate = info.gate,
        addr = socket_addr:match("([^:]+):(.*)"),
      })
    end
  end
end

--- client断开
-- @within SOCKET
function SOCKET.close(fd)
  skynet.error('KEY POINT', 'hall: client active socket close:', fd)
  close_connection(fd)
end

--- client出错
-- @within SOCKET
function SOCKET.error(fd, msg)
  skynet.error('KEY POINT', 'hall: client socket error:', fd, msg)
  close_connection(fd)
end

--- clientsocket warning
-- @within SOCKET
function SOCKET.warning(fd, size)
  skynet.error('KEY POINT', 'hall: client socket warning:', fd, size)
end

return SOCKET

end
