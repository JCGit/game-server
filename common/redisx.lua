--- redisx redis服务高级接口
local redisx = {}

local skynet = require 'skynet'

local tonumber = tonumber

local REDIS

-- 存储类型
-- 默认存储Lua 表的 序列化字符串
-- 开启dev标记后，同时存一份可读格式的

--- debug接口 方便在main服务中调试接口
function redisx.init(redis)
  REDIS = redis
end

local enable_leveldb_flag = true

skynet.init(function ()
  REDIS = skynet.queryservice('redis')
end)

function redisx.incr(key)
  return skynet.call(REDIS, 'lua', 1, 'incr', key)
end

--- redis set lua value
function redisx.setvalue(key, ...)
  return skynet.send(REDIS, 'lua', 'set', key, skynet.packstring(...))
end

--- redis get
function redisx.getvalue(key)
  return skynet.unpack(skynet.call(REDIS, 'lua', 1, 'get', key))
end

function redisx.setstring(key, value)
  return skynet.send(REDIS, 'lua', 'set', key, value)
end

function redisx.getstring(key)
  return skynet.call(REDIS, 'lua', 1, 'get', key)
end

function redisx.del(...)
  return skynet.send(REDIS, 'lua', 'del', ...)
end

function redisx.rename(key, newkey)
  return skynet.send(REDIS, 'lua', 'rename', key, newkey)
end

--- redis hget
function redisx.hsettable(key, field, value)
  local ret = skynet.send(REDIS, 'lua', 'hset', key, field, skynet.packstring(value))
  return ret
end

function redisx.hgettable(key, field)
  local r = skynet.call(REDIS, 'lua', 1, 'hget', key, field)
  local data = skynet.unpack(r)

  return data
end

-- flag true表示要将key转成number
function redisx.hgetall_all_value(table, flag)
  local tmp = skynet.call(REDIS, 'lua', 1, 'hgetall', table)
  local len = #tmp / 2
  local lists = {}
  for i = 1, len do
    local key = tmp[i * 2 -1 ]
    if flag then key = tonumber(key) end
    lists[key] = skynet.unpack(tmp[i * 2])  
  end
  return lists
end

function redisx.hkeys(key)
  return skynet.call(REDIS, 'lua', 1, 'hkeys', key)
end

function redisx.hsetstring(key, field, value)
  return skynet.send(REDIS, 'lua', 'hset', key, field, value)
end

function redisx.hgetstring(key, field)
  return skynet.call(REDIS, 'lua', 1, 'hget', key, field)
end

function redisx.hdel(key, field)
  local ret = skynet.call(REDIS, 'lua', 1, 'hdel', key, field)
  return ret 
end

function redisx.hsetnx(key, field, value)
  return skynet.call(REDIS, 'lua', 1, 'hsetnx', key, field, value)
end

function redisx.setnx(key, value)
  return skynet.call(REDIS, 'lua', 1, 'setnx', key, value) == 1
end

function redisx.incrby(key, increment)
  return tonumber(skynet.call(REDIS, 'lua', 1, 'incrby', key, increment))
end


function redisx.hlen(key)
  return skynet.call(REDIS, "lua", 1, 'hlen', key)
end

------------------------------------------------
-----------   Sets   ---------------------------
------------------------------------------------

function redisx.sismember(key, member)
  return skynet.call(REDIS, "lua", 1, "sismember", key, member)
end

function redisx.sadd(key, ...)
  return skynet.call(REDIS, "lua", 1, "sadd", key, ...)
end

return redisx
