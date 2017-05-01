local skynet = require "skynet"
local os = os
local table = table

local function logger(str)
  return function (...)
    local uin
    local t = {...}
    if not info or not info.uin then
      uin = t[1]
      table.remove(t, 1)
    else
      uin = info.uin
    end
    skynet.send(".game_logger","lua", str:lower(), os.date("%Y-%m-%d %H:%M:%S"), uin, table.concat(t, ' '))
  end
end

local M = {
  TRACE = logger "TRACE",
  DEBUG = logger "DEBUG",
  INFO  = logger "INFO",
  WARN  = logger "WARN",
  ERR   = logger "ERR",
  FATAL = logger "FATAL",
}

setmetatable(M, {
  __call = function(t)
    for k, v in pairs(t) do
      _G[k] = v
    end
  end,
})

return M
