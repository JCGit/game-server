--- bootstrap 服务, 启动完服务器后就结束
local skynet = require 'skynet'
require "skynet.manager"

skynet.start(function ()
  -- 基础服务
  local settings = require 'settings'
  skynet.uniqueservice('debug_console', settings.console_port)

  skynet.uniqueservice('redis')
  print("start up mongodb")
  skynet.uniqueservice("mongodb")

  -- 日志服务
  assert(skynet.uniqueservice('game_logger'), 'init game_logger failed')

  -- 网关服务 (skynet标准服务)
  local client_gate = skynet.newservice("gate")

  -- 大厅服务
  local hall = skynet.newservice("hall")
  skynet.name(".hall", hall)

  local gm = skynet.newservice("gmservice")
  skynet.name(".gm", gm)

  skynet.name(".room_mgr", skynet.uniqueservice("room_mgr"))

  local gate_conf = {
    port       = settings.gate_port,
    maxclient  = settings.gate_max_client,
    nodelay    = true,
    watchdog   = hall,
  }
  skynet.call(client_gate, "lua", "open", gate_conf)

  -- 大厅服务
  local hall_conf = {
    gate      = client_gate,
    hallName  = settings.hallName
  }

  skynet.call(hall, "lua", "open", hall_conf)
  skynet.exit()
end)

