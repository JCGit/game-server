local require, assert, type, pairs = require, assert, type, pairs
local table = table

local skynet     = require "skynet"
local crypt      = require 'crypt'
local des_decode = crypt.desdecode
local protobuf   = require 'protobuf'
local pb_decode  = protobuf.decode
local inspect_client_log = require "inspect_client_log"
local constant   = require "constant"
local hash_lib   = require "hash"
local settings   = require "settings"
local utils      = require "utils"

local redisx   = require 'redisx'

require 'agent.global'

local modules = {}
local modules_arr = {}
msg_handlers = {}
local datas
local last_active_time
local CMD = {}
local leaveTime = 0

-- 当不关闭hash检查时, 用默认值函数替换掉
if settings.hash_shut_down then
  function hash_lib.hashcode()
    return 0
  end
end

local function register_module(name, pack)
  modules[name] = require(pack)
  table.insert(modules_arr, modules[name])
end

local function load_agent_module()
  event.removeAllEventListeners()

  register_module("profile_mod" , "agent.profile")
  register_module("room_mod"    , "agent.room")
  register_module("record_mod"  , "agent.record")

  for _, mod in pairs(modules) do
    if type(mod) == 'table' then
      if mod.register_event then mod.register_event() end
      if mod.register_handler then mod.register_handler() end
      if mod.modules then mod.modules(modules) end
      for k, v in pairs(mod.CMD or {}) do
        assert(not CMD[k])
        CMD[k] = v
      end
    end
  end
  collectgarbage('collect')
end

function load_data(mod_name, uin)
  datas = datas or {}
  local mod = modules[mod_name]
  if type(mod) == 'table' and mod.redis_key then
    local redis_key = mod.redis_key
    local tbl = {}
    if type(redis_key) == 'string' then
      local data = redisx.hgettable(redis_key, uin) or mod.init_data()
      assert(type(data) == "table")
      mod.data(data)
      tbl[redis_key] = {
        data = data,
        hash = hash_lib.hashcode(data),
      }
    else
      local data_tbl = {}
      for _, key in ipairs(redis_key) do
        local d = redisx.hgettable(key, uin) or mod.init_data[key]()
        assert(type(d) == "table")
        tbl[key] = {
          data = d,
          hash = hash_lib.hashcode(d),
        }
        data_tbl[key] = d
      end
      mod.data(data_tbl)
    end
    datas[mod_name] = tbl
  end
end

function save_data(mod_name, uin, check_hash)
  if not datas[mod_name] then return end
  for redis_key, v in pairs(datas[mod_name]) do
    local save = true
    if check_hash then
      local h = v.hash
      v.hash = hash_lib.hashcode(v.data)
      if h == v.hash then
        save = false
      end
    end
    if save then
      redisx.hsettable(redis_key, uin, v.data)
    end
  end
end

function save_all_db(uin, check_hash)
  assert(uin)
  for mod_name in pairs(datas) do
    save_data(mod_name, uin, check_hash)
  end
end

--- 客户端在登录服完成认证之后，创建agent，并login初始化
function CMD.login(data)
  skynet.error("gate login ",inspect(data))
  info.hall          = data.hall
  info.userid         = data.userid
  info.secret         = data.secret
  info.uin            = data.uin
  info.pf             = data.pf

  datas = {}
  local uin = info.uin
  for mod_name in pairs(modules) do
    load_data(mod_name, uin)
  end

  -- 当用户未初始化时，很可能是第一次进入游戏，做一次保存操作
  if not modules.profile_mod.isinit() then
    save_all_db(info.uin)
  end

  local function save_all_db_timer ()
    local save_db_internal = 60 * 100
    skynet.timeout(save_db_internal, save_all_db_timer)
    save_all_db(info.uin, true)
  end

  last_active_time = skynet.now()
  local function check_online_timer ()
    local check_online_internal = 30 * 100
    skynet.timeout(check_online_internal, check_online_timer)
    local t = skynet.now() - last_active_time
    local MAX_NO_ACTIVE_TIME = 1 * 60 * 100 * 100
    if t >= MAX_NO_ACTIVE_TIME then
      CMD.logout()
    end
  end

  save_all_db_timer()
  check_online_timer()

  event.dispatchEvent(events.player_login)
  skynet.error('KEY POINT', "agent login: ", info.userid, skynet.self())
end

--- 客户端连上游戏服，并通过认证，开始处理gate client消息
-- gate 网关地址
function CMD.enter(data)
  if skynet.call(data.gate, 'lua', 'forward', data.client_fd) then
    skynet.error('KEY POINT', 'enter ok', info.userid, info.uin, data.client_fd)
    info.fd = data.client_fd
    info.addr = data.addr
    last_active_time = skynet.now()
    skynet.error("socket addr", data.addr)

    send_client_msg = message.mk_send_message(info.fd, info.secret)
    return true
  else
    skynet.error('KEY POINT', 'enter failed', info.userid, info.uin, data.client_fd)
    return false
  end
end

--- 客户端连接断开或网络错误
function CMD.leave()
  info.fd = nil
  send_client_msg = nil

  INFO("Player leave: ", info.uin)

  event.dispatchEvent(events.player_offline)

  skynet.error('KEY POINT', 'enter leave', info.userid, info.uin)
  return NO_RETURN
end

--- call by hall's kick handler
-- @see hall.kick
-- @within CMD
function CMD.logout()
  skynet.error('KEY POINT', 'enter logout', info.userid, info.uin)
  event.dispatchEvent(events.player_logout)
  save_all_db(info.uin)

  skynet.call(info.hall, 'lua', 'logout', info.userid)
  skynet.exit()
  return NO_RETURN
end

local skynet_tostring = skynet.tostring

skynet.register_protocol {
  name   = "client",
  id     = skynet.PTYPE_CLIENT,
  unpack = function (msg, sz)
    local buf = des_decode(info.secret, skynet_tostring(msg, sz))
    local msgid = string.unpack('>I4', buf)
    local req = pb_decode(message.req_dict[msgid], buf:sub(5))
    if msgid ~= 11 then --心跳
      INFO(string.format("[R] %d %s %s", msgid,
        message.req_dict[msgid],
        inspect_client_log(req, inspect)))
    end
    return msgid, req
  end,

  dispatch = function (session, source, msgid, msg)
    last_active_time = skynet.now()
    local handler = msg_handlers[msgid]
    if handler then
      return handler(msgid, msg)
    else
      WARN('unknown msgid: ', msgid)
    end
  end,
}

skynet.start(function()
  load_agent_module()
  skynet.dispatch("lua", function(session, source, command, subcommand, ...)
    if CMD[command] then
      local r = CMD[command](subcommand, ...)
      if r ~= NO_RETURN then
        return skynet.retpack(r)
      end
    else
      local r = modules[command][subcommand](...)
      if r ~= nil then
        return skynet.retpack(r)
      end
    end
  end)
end)
