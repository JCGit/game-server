--- hall 服务
-- 管理客户端gate转发的socket消息,管理逻辑服与agent
-- @module hall
local skynet  = require "skynet"
require "skynet.manager"

local profile = require 'profile'
local crypt   = require 'crypt'
local inspect = require 'inspect'
local settings = require 'settings'
local cluster = require "cluster"
local redisx = require "redisx"
local constant = require "constant"
local utils = require "utils"

local b64encode = crypt.base64encode

local profile_info = {}

local info = {
  gate       = false, -- 网关服务
  login      = false, -- 认证服务
  hallName  = false,
}

local NORET = {}

-- 在线用户
-- 通过gate的认证后添加, 连接断开或登出后删除
local connection = {}
local user_login = {}

local SOCKET = require 'hall.socket' {
  info       = info,
  connection = connection,
  user_login = user_login,
}

local CMD = {}
local local_logger

--- 启动大厅 向登录服务 注册登陆点；启动逻辑服
-- @within CMD
function CMD.open(conf)
  info.gate  = conf.gate
  info.hallName = conf.hallName

  local hall = skynet.self()

  local ok, ret = xpcall(cluster.call, debug.traceback, "loginnode", ".loginservice", "register_hall",  info.hallName, skynet.self())
  if not ok then
      skynet.error(ret)
  end

  local ok, ret = xpcall(cluster.call, debug.traceback, "centernode", ".centerservice", "register_hall",  info.hallName, skynet.self())
  if not ok then
    skynet.error(ret)
  end

  cluster.register(info.hallName)
  cluster.open(conf.hallName .. "node")
end

--- 关闭大厅
-- @within CMD
function CMD.stophall()
  for _, v in pairs(user_login) do
    skynet.send(v.agent, 'lua', 'logout', 'kill')
  end
  skynet.call(info.gate, "lua", "close")
end

--- 登录
-- @string uin 用户唯一id
-- @string secret 通讯密钥
-- @ret int 用户子id
-- @within CMD
function CMD.login(uin, secret, pf)
  local uin = tonumber(uin)
  local agent = skynet.newservice("agent")
  local data = {
    hall          = skynet.self(),
    userid         = uin,
    secret         = secret,
    uin            = tonumber(uin),
    pf             = pf,
  }
  if user_login[uin] then
    CMD.kick(uin)
  end
  print ("hall login")
  skynet.call(agent, "lua", "login", data)

  user_login[uin] = {
    uin              = uin,
    secret           = secret,
    conn_idx         = 0, -- 与gate断开重连后客户端会增加此索引
    agent            = agent,
    fd               = false,
    ip               = false,
    pf               = pf,                -- 平台id
  }
  return uin
end

--- call by agent, agent登出后给大厅上报，大厅再上报给login 已成功登出
-- @within CMD
function CMD.logout(uin)
  local uin = tonumber(uin)
  local u = user_login[uin]
  if u then
    user_login[uin] = nil
    if u.fd then
      skynet.call(info.gate, 'lua', 'kick', u.fd) -- 关闭连接
      connection[u.fd] = nil
    end
  end
end

--- call by login 可能会被调用多次，如果客户端多次重复登陆的话
-- XXX kick的流程也可以修改成 大厅直接通知gate 关闭连接，并更新在线用户和
-- 登录用户列表；上报login登录成功，再通知agent 客户端已登出
-- @within CMD
function CMD.kick(uin, subid)
  local uin = tonumber(uin)
  local u = user_login[uin]
  if u then
    pcall(skynet.call, u.agent, 'lua', 'logout')
  end
end

-- 根据 uin 获取用户的 agent
function CMD.get_agent(uin)
  local uin = tonumber(uin)
  local u = user_login[uin]

  if u and u.agent then
    return u.agent
  end

  return nil
end

skynet.start(function()

  skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
    if cmd == "socket" then
      return SOCKET[subcmd](...) -- socket api don't need return
    else

      if dev_hall_log then
        skynet.error('command: ', cmd, ...)
      end

      profile.start()
      local f = CMD[cmd]
      local ok, ret = xpcall(f, debug.traceback, subcmd, ...)

      local time = profile.stop()
      local p = profile_info[cmd]
      if p == nil then
          p = { n = 0, ti = 0 }
          profile_info[cmd] = p
      end
      p.n = p.n + 1
      p.ti = p.ti + time

      if not ok then
          skynet.error(string.format("Handle message(%s) failed: %s", cmd, ret))
          return skynet.ret()
      elseif ret ~= NORET then
          return skynet.retpack(ret)
      end
    end
  end)
end)
