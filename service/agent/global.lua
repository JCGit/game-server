local require, assert, type = require, assert, type

local skynet = require "skynet"

inspect = require 'inspect'
event   = require 'event'
message = require 'message'
events  = require 'agent.events'

NO_RETURN = {}

info = {
  hall           = false, -- 大厅服务
  userid         = false,
  secret         = false,
  fd             = false,
  uin            = false,
}

function register_msg_handler (msgid_name, handler)
  local msgid = assert(message.MI[msgid_name], 'unknown msgid')
  if msg_handlers[msgid] then
    WARN('warning! msg handler: ', msgid_name)
  end
  assert(type(handler) == 'function')
  msg_handlers[msgid] = handler
end

function send_message(msgid, msg)
  assert(msgid)
  return send_client_msg and send_client_msg(msgid, msg) or nil
end

function send_status (rpcid)
  return function (status_code)
    send_message(rpcid, {status=status_code})
  end
end

function send_msg(msgid_name, msg)
  local msgid = assert(message.MI[msgid_name], 'unknown msgid')
   return send_client_msg and send_client_msg(msgid, msg) or nil
end

require "logger_api"()
