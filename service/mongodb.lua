local skynet = require "skynet"
require "skynet.manager"
local mongo = require "mongo"
local bson = require "bson" 
local utils = require "utils"

local host = "127.0.0.1"
local db_client
local db_name = "poke"
local db

local CMD = {}

function CMD.init()
	db_client = mongo.client({host = host})
	db_client:getDB(db_name)
	db = db_client[db_name]
end

local function init()
	db_client = mongo.client({host = host})
	db_client:getDB(db_name)
	db = db_client[db_name]
	assert(db ~= nil, "dbname " .. db_name  .. "not exist")
end

function CMD.findOne(cname, selector, field_selector)
	return db[cname]:findOne(selector, field_selector)
end

function CMD.find(cname, opt)
	local meta = db[cname]:find(opt.selector, opt.field_selector)
	if opt.sort then
		meta = meta:sort(opt.sort)
	end
	if opt.skip then
		meta = meta:skip(opt.skip)
	end
	if opt.limit then
		meta = meta:limit(opt.limit)
	end

	local set 
	while meta:hasNext() do
		set = set and set or {}  
		local node = meta:next()
		table.insert(set, node)
	end
	return set
end

function CMD.update(cname, ...)
	local collection = db[cname]
	collection:update(...)
	local r = db:runCommand("getLastError")
	if r.err ~= bson.null then
		return false, r.err
	end

	if r.n <= 0 then
		skynet.error("mongodb update "..cname.." failed")
	end

	return ok, r.err
end

function CMD.safe_insert(cname, doc)
	local collection = db[cname]
	local ret = collection:safe_insert(doc)
	
	return ret
end

local ops = {'insert', 'batch_insert', 'delete'}
for _, v in ipairs(ops) do
    CMD[v] = function(cname, ...)
        local c = db[cname]
        local ret = c[v](c, ...)
        local r = db:runCommand('getLastError')
        local ok = r and r.ok == 1 and r.err == bson.null
        if not ok then
            skynet.error(v.." failed: ", r.err, tname, ...)
        end
        --return ok, r.err
        ret.ok = ok
        ret.err = r.err
        return ret
    end
end

skynet.start(function()
	init()

	skynet.dispatch("lua", function (session, addr, command, ...)
		print("mongodb service cmd ", command)
		local f = CMD[command]

		if not f then
			print("not this command" .. command)
		end

		local ok, ret = xpcall(f, debug.traceback, ...)

		if ok then
			print("mongodb service over cmd ", command)
			skynet.retpack(ret)
		else
			print("ret -------------- ", ret)
		end
	end)

	skynet.register("mongodb")
end)
