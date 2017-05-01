local skynet = require "skynet"
require "skynet.manager"
local settings = require "settings"

local log_level = settings.log_level.LOG_DEFAULT
local log_trace = settings.log_level.LOG_TRACE
local log_debug = settings.log_level.LOG_DEBUG
local log_info = settings.log_level.LOG_INFO
local log_warn = settings.log_level.LOG_WARN
local log_err = settings.log_level.LOG_ERROR
local log_fatal = settings.log_level.LOG_FATAL

local COLOR_RED    = '\x1b[31m'
local COLOR_GREEN  = '\x1b[32m'
local COLOR_YELLOW = '\x1b[33m'
local COLOR_RESET  = '\x1b[0m'

local function filter_msg(color, level, time, uin, str)
  local msg
  msg = string.format("%s %s %s %s %s %s", color, level, time, uin, str, COLOR_RESET)

  if msg then
    skynet.error(string.format("%s %s %s %s %s", color, level, uin, str, COLOR_RESET))
  end
end

local CMD = {}

function CMD.trace(...)
  if  log_trace >= log_level then
    filter_msg(COLOR_GREEN, "[TRACE]", ...)
  end
end

function CMD.debug(...)
  if log_debug >= log_level then
    filter_msg(COLOR_GREEN, "[DEBUG]", ...)
  end
end

function CMD.info(...)
  if log_info >= log_level then
    filter_msg(COLOR_GREEN, "[INFO]", ...)
  end
end

function CMD.warn(...)
  if log_warn >= log_level then
    filter_msg(COLOR_YELLOW, "[WARN]", ...)
  end
end

function CMD.err(...)
  if log_err >= log_level then
    filter_msg(COLOR_RED, "[ERROR]", ...)
  end
end

function CMD.fatal(...)
  if log_fatal >= log_level then
    filter_msg(COLOR_RED, "[FATAL ERROR]", ...)
  end
end

-- 此接口仅影响逻辑日志
function CMD.set_level(level)
  log_level = level
end

local traceback =  debug.traceback
skynet.start(function()
  skynet.dispatch("lua", function(_, _, command, ...)
    local f = CMD[command]
    if not f then
      skynet.error(("game_logger unhandled message(%s)"):format(command))
      return
    end

    local ok, ret = xpcall(f, traceback, ...)
    if not ok then
      skynet.error(("game_logger handle message(%s) failed : %s"):format(command, ret))
    end
  end)
  skynet.register("." .. SERVICE_NAME)
end)
