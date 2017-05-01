local skynet = require "skynet"
local socket = require "socket"

local CMD = {}
function CMD.open(conf)
	local id = socket.listen(conf.host, conf.port)

	local webagents = {}
	for i=1, conf.num do
		local agent = skynet.newservice("webagent")
		skynet.call(agent, "lua", "open", conf.appname)
		webagents[i] = agent
	end

	skynet.error("Listen web port " .. conf.port)

	local balance = 1
	socket.start(id, function(id, addr)
		skynet.send(webagents[balance], "lua", "http", id)
		balance = balance + 1
		if balance > #webagents then
			balance = 1
		end 
	end)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		return skynet.retpack(CMD[cmd](...))
	end)
end)

