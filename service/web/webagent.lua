local skynet = require "skynet"
local socket = require "socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local table = table
local string = string

local route = {
}

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

local function process_request(url, method, header, body)
	skynet.error("http request :", method, url)

	local path, query = urllib.parse(url)
	query = query and urllib.parse_query(query) or nil

	print("path : query ", path, query)

	local handler = route[path]
	if not handler then
		return 404, "404", {
			['Content-Type'] = 'text/html',
        	['Server'] = 'skynetweb',
     	}
	end

	return handler(method, query, body)
end

-- http处理
local function process(id)
	socket.start(id)
	-- limit request body size to 8192 (you can pass nil to unlimit)
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)

	if code then
		if code ~= 200 then
			response(id, code)
		else
			response(id, process_request(url, method, header, body))
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("socket closed")
		else
			skynet.error(url)
		end
	end
	socket.close(id)
end

local CMD = {}
function CMD.open(appname)
	--print("appname ----- ", appname)
	-- service/center/center_webapp.lua
	--io.open(appname, "rb"):read("a")
	load(io.open(appname, "rb"):read("a"), "@" .. appname)(route)
end

skynet.start(function()
	skynet.dispatch("lua", function (_, _, cmd, ...)
		if cmd == "http" then
			process(...)
		else
			local f = CMD[cmd]
			local ret = f(...)
			skynet.retpack(ret)
		end
	end)
end)
