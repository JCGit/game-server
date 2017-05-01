#!/usr/bin/env lua53
assert(_VERSION == "Lua 5.3")

package.path  = "common/?.lua;lualib/?.lua;client/?.lua;skynet-dist/lualib/?.lua;client/sockethttp/?.lua"
package.cpath = "skynet-dist/luaclib/?.so;luaclib/?.so;client/sockethttp/?.so;client/termfx-0.7-1/?.so"

local assert = assert
local string = string
local table = table
local socket  = require 'socket'
local crypt   = require "crypt"
local inspect = require 'inspect'
local settings = require 'settings'
local utils = require "utils"

local protobuf = require 'protobuf'
local pb_decode = protobuf.decode
local pb_encode = protobuf.encode
protobuf.register(io.open("proto/game.pb", "rb"):read('a'))

local function clear_metatable (tb)
  setmetatable(tb, nil)
  for k, v in pairs(tb) do
    if type(v) == 'table' then
      clear_metatable(v)
    end
  end
end

local rpc_info = require 'rpc_info'
local req_t    = rpc_info.req_dict
local res_t    = rpc_info.res_dict
local MI       = rpc_info.rpc_dict
local MN       = {}

for k, v in pairs(MI) do
  MN[v] = k
end

local termfx = require "termfx"
local ui = require 'simpleui'

local output = {}
local function p(...)
  local l = {}
  for _, v in ipairs {...} do
    table.insert(l, tostring(v))
  end
  table.insert(output, table.concat(l, ' '))
end


local function block_read_pack(sock)
  local len = sock:receive(2)
  if len then
    len = len:byte(1) * 256 + len:byte(2)
    local msg, err, parts = sock:receive(len)
    if msg and #msg == len then
      return msg
    else
      sock:close()
      return nil, err
    end
  end
end

local function mk_recv(sock, secret)
  return function()
    sock:settimeout(0)
    local len, r = sock:receive(2)
    if len then
      len = len:byte(1) * 256 + len:byte(2)
      sock:settimeout(nil) -- or 1 seconds
      local msg, err = sock:receive(len)
      if msg then
        assert(#msg == len)

        local buf = crypt.desdecode(secret, msg)
        local msgid = string.unpack('>I4', buf)
        local res_msg = pb_decode(res_t[msgid], buf:sub(5))
        protobuf.extract(res_msg)
        clear_metatable(res_msg)
        return true, msgid, res_msg

      else
        return false, err
      end
    else
      if r == 'timeout' then
        return nil
      elseif r == 'closed' then
        return false, 'socket close'
      end
    end
  end
end

local function mk_send(sock, secret)
  return function (msgid, msg)
    local pb_buf = pb_encode(req_t[msgid], msg)
    local buf = string.pack('>I4c' .. #pb_buf, msgid, pb_buf)
    sock:settimeout(0.5)
    sock:send(string.pack('>s2', crypt.desencode(secret, buf)))
  end
end

local msg_tbl = {
  {
    "login",
    {
      openid = "yufsfasd",
      sex = 1,
      name = "hello name",
      imgurl = "http://pic22.nipic.com/20120630/9713815_181736012305_2.jpg",
    }
  },
  { "openRoom", {roomType="FIVE_ROUNDS",dealerType="HAVE_DEALER", dealerMin=3,publicMaxChip=30} },
  { "enterRoom", { roomID=663982 } },
  { "requestRoomCache", {} },
  { "leaveRoom", {} },
  { "destoryRoom", {} },
  { "startVote", {} },
  { "vote", {agree=true} },
  { "playerReady", {} },
  {"bet",{uin=1000001,public=false,power=2}},
  {"lookcard",{}},
  {"showcard",{}},
  {"gameReady",{}},
  {"bet",{uin=1000001,public=true,power=20}},
  {"getRecord", {uin=1000001}},
}

local function print_msg_list(msg_list, x, y, with_index)
  local idx = #msg_list
  for i = y, 2, -1 do
    local m = msg_list[idx]
    if m then
      local index = with_index and (idx .. ". ") or ""
      local rpc_name = m[1]
      local rpc_value = (type(m[2]) == "table") and inspect(m[2]) or m[2]
      termfx.printat(x, i, index .. rpc_name .. ' ' .. rpc_value)
    else
      break
    end

    idx = idx - 1
  end
end

local function main(ip, port, uid, worldId, secret,subid)
  termfx.init()
  termfx.inputmode(termfx.input.ALT + termfx.input.MOUSE)
  termfx.outputmode(termfx.output.COL256)
  local sock = socket.connect(ip, port)

  local handshake = string.format("%s@%s#%s:%d",
    crypt.base64encode(uid),
    crypt.base64encode(worldId),
    crypt.base64encode(subid), 1)

  local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

  local hs = handshake .. ':' .. crypt.base64encode(hmac)
  sock:send(string.pack(">s2", hs))

  local res = block_read_pack(sock)
  if not res then
    return p 'connect gate error'
  end

  local recv_msg = mk_recv(sock, secret)
  local send_msg = mk_send(sock, secret)

  local function act_when_input(input)
    if tonumber(input) ~= nil then
      local msg = msg_tbl[tonumber(input)]
      send_msg(MI[msg[1]], msg[2])
    else
      local rpc_name, rpc_value = input:match("(%w+)%s+(.+)")
      local request = load("return " .. rpc_value)
      send_msg(MI[rpc_name], request())
    end
  end

  local ok, err = pcall(function()

    local msg_list = {}
    local input
    local string = {}


    local quit = false
    while true do
      termfx.clear(termfx.color.WHITE, termfx.color.BLACK)

      local w, h = termfx.size()
      local width = math.floor(w/2)

      do
        ui.box(2, 2, width, h-10)
        ui.box(w/2, 2, width, h-10)
        print_msg_list(msg_list, 2, h-10)
        print_msg_list(msg_tbl, w/2, h-10, true)
      end

      termfx.printat(2, h-1, input)
      termfx.printat(2, h, table.concat(string, ""))
      termfx.present()

      local evt = termfx.pollevent(100)

      if evt then
        if evt.type == 'key' then
          if evt.key == termfx.key.CTRL_C then
            break
          elseif evt.key == termfx.key.BACKSPACE2 then
            table.remove(string)
          elseif evt.key == termfx.key.ENTER then
            input = table.concat(string, '')
            string = {}
            pcall(act_when_input, input)
          elseif evt.key == termfx.key.SPACE then
            table.insert(string, ' ')
          else
            table.insert(string, evt.char)
          end
        end

      else
        local r, msgid, msg = recv_msg()
        if r == true then
          table.insert(msg_list, {
            MN[msgid] or msgid,
            inspect(msg)
          })
        elseif r == false then
          p('网络断开，结束客户端', msgid)
          break
        end
      end
    end
  end)

  termfx.shutdown()
  if not ok then
    print("Error: ", err)
  end
  print(':\n', table.concat(output, '\n'))

end

local function auth()
  local sock = socket.connect('127.0.0.1', settings.login_conf.login_port)
  local challenge = crypt.base64decode(sock:receive('*l'))
  local clientkey = crypt.randomkey()
  sock:send(crypt.base64encode(crypt.dhexchange(clientkey)) .. '\n')

  local line = crypt.base64decode(sock:receive '*l' )
  local secret = crypt.dhsecret(line, clientkey)

  local hmac = crypt.hmac64(challenge, secret)
  -- 5. 回应服务器的握手挑战码，确认握手正常
  sock:send(crypt.base64encode(hmac) .. '\n')

  local user_profile
  user_profile = 'client/user_info.txt'

  local token = {pf = '1010',user='teefe', pass='123456789',worldId = 2}
  local rf = io.open(user_profile, 'rb')
  if rf then
    token.user = rf:read 'l'
    token.pass = rf:read 'l'
    rf:close()
  else
    token.user = utils.randomstring(15)
    token.pass = 'np:' .. crypt.base64encode(crypt.randomkey())
  end
  local function encode_token(token)
    return string.format("%s@%s:%s:%s",
      crypt.base64encode(token.user),
      crypt.base64encode(token.worldId),
      crypt.base64encode(token.pass),
      crypt.base64encode(token.pf))
  end

  -- 6. DES加密发送 token串
  local etoken = crypt.desencode(secret, encode_token(token))
  sock:send(crypt.base64encode(etoken) .. '\n')
  -- 服务器解密后调用定制的auth和login handler处理客户端请求

  -- 7. 从服务器读取 登录结果： 状态码 和subid
  local result = sock:receive '*l'
  local code = tonumber(string.sub(result, 1, 3))
  assert(code == 200)
  sock:close()

  local subid = crypt.base64decode(string.sub(result, 5))
  local ip, port, uid, subid = subid:match("([^:]+):([^:]+)@([^@]+)@(.+)")
  print(ip, port, uid, subid)

  io.open(user_profile, 'wb'):write(token.user, '\n', token.pass)

  return ip, port, uid, token.worldId, secret, subid
end

main(auth())


