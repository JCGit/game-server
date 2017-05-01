local skynet = require 'skynet.manager'
local cluster = require "cluster"
local settings = require 'settings'

skynet.start(function ()
  local center_conf = settings.center_conf

  skynet.uniqueservice('debug_console', center_conf.console_port)

  local redis = skynet.uniqueservice('redis')
  local center  = skynet.newservice("centerservice")

  skynet.name(".centerservice", center)

  local web_conf = {
  	host = "0.0.0.0",
  	port = 8100,
  	num = 3,
  	appname = "service/center/center_webapp.lua"
  }
  local center_web = skynet.newservice("webgate")
  skynet.call(center_web, "lua", "open", web_conf)

  cluster.open "centernode"
  skynet.exit()
end)

