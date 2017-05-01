local skynet = require 'skynet'
require 'skynet.manager' -- import skynet.abort()
local redis = require 'redis'
local settings = require 'settings'

skynet.start(function ()

  local db_conf = settings.redis_conf
  local ok, hredis = pcall(redis.connect, db_conf)

  if not ok then
    print('cannot connect to redis!')
    return skynet.abort()
  end

  skynet.dispatch("lua", function(_, _, cmd, subcmd, ...)

  --  skynet.error('command: ', cmd, subcmd, ...)

    local hredis = hredis

    if cmd == 1 then
      return skynet.retpack(hredis[subcmd](hredis, ...))
    else
      return hredis[cmd](hredis, subcmd, ...)
    end
  end)
end)
