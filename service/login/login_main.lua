--- bootstrap 服务, 启动完服务器后就结束
local skynet = require 'skynet.manager'
local cluster = require "cluster"

skynet.start(function ()
    local settings = require 'settings'

    skynet.uniqueservice('debug_console', settings.login_conf.console_port)

    local redis = skynet.uniqueservice('redis')

    local loginservice = skynet.newservice("loginservice")

    skynet.name(".loginservice", loginservice)

    skynet.call(loginservice, "lua", "init")

    cluster.open "loginnode"

    skynet.exit()
end)

