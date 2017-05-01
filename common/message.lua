local skynet   = require "skynet"
local crypt    = require 'crypt'
local protobuf = require 'protobuf'
local setting  = require 'settings'
local socketdriver = require 'socketdriver'
local inspect = require "inspect"
local inspect_client_log = require "inspect_client_log"
local utils    = require "utils"
require "logger_api"()

local rpc_info = (import or require) 'rpc_info'

protobuf.register_file("proto/game.pb")

local req_dict = rpc_info.req_dict
local res_dict = rpc_info.res_dict

local pb_decode = protobuf.decode
local pb_encode = protobuf.encode

local skynet_tostring = skynet.tostring
local des_decode = crypt.desdecode
local des_encode = crypt.desencode

local M = {}

function M.unpack_message(secret, msg, sz)
  local ebuf = skynet_tostring(msg, sz)
  local buf = des_decode(secret, ebuf)
  local msgid = string.unpack('>I4', buf)
  return msgid, pb_decode(req_dict[msgid], buf:sub(5))
end

function M.unpack_string_message(secret, msg)
  local buf = des_decode(secret, msg)
  local msgid = string.unpack('>I4', buf)
  return msgid, pb_decode(req_dict[msgid], buf:sub(5))
end

local function print_client_msg(msgid, msg, uin)
  local str = inspect_client_log(msg, inspect)
  local tail = ""
  if setting.client_short_info then
    local max_len = 44
    tail = #str > max_len and "..." or ""
    str = str:sub(1, max_len)
  end
  -- 不打印心跳包
  if msgid ~= 11 then
    local log_msg = string.format("[S] %d %s %s%s", msgid, res_dict[msgid], str, tail)
    if not uin then
      INFO(log_msg)
    else
      INFO(uin, log_msg)
    end
  end
end

function M.mk_send_message (fd, secret, uin)
  assert(type(fd) == 'number')
  assert(type(secret) == 'string')

  return function(msgid, msg)
    local pb_buf = pb_encode(res_dict[msgid], msg)
    local buf = string.pack('>I4c' .. #pb_buf, msgid, pb_buf)

    print_client_msg(msgid, msg, uin)

    return socketdriver.send(fd, string.pack('>s2', des_encode(secret, buf)))
  end
end

function M.send_message(fd, secret, msgid, msg)
  local pb_buf = pb_encode(res_dict[msgid], msg)
  local buf = string.pack('>I4c' .. #pb_buf, msgid, pb_buf)
  local e_buf = des_encode(secret, buf)
  print_client_msg(msgid, msg)
  socketdriver.send(fd, string.pack('>s2', e_buf))
end

M.MI = rpc_info.rpc_dict
M.MN = {}

for k, v in pairs(M.MI) do
  M.MN[v] = k
end

M.req_dict = req_dict
M.res_dict = res_dict

return M
