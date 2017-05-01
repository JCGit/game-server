local utils = require 'utils'

local send_msg, send_message, send_status = send_msg, send_message, send_status
local simple_copy_obj = utils.simple_copy_obj
local event, events = event, events
local profile_redis_key = 'user:profile'

local M = { CMD={} }
local CMD = M.CMD

local profile, uin

--- 玩家初始信息
local profile_t = {
  uin         =  1,   --  唯一ID
  room_ticket   =  20,
  init        =  false
}

local function player_update ()
  if profile_update then
    local t = profile_update
    profile_update = nil
    send_msg('pushBasicPlayerInfo', t)
  end
end

function M.room_ticket(num)
  if not num or num == 0 then
    return profile.room_ticket
  end
  if profile.room_ticket + num < 0 then
    return false
  end
  profile.room_ticket = profile.room_ticket + num
  profile_update = profile_update or {}
  profile_update.room_ticket = profile.room_ticket

  -- 需要从房间里边调此方法，需要手动触发事件
  event.dispatchEvent(events.profile_update)
  return profile.room_ticket
end

function M.basic_profile()
  return {
    uin        = profile.uin,
    name       = profile.name,
    sex        = profile.sex,
    imgurl = profile.imgurl,
    ip         = profile.ip,
    ticket     = profile.room_ticket,
    openid     = profile.openid,
  }
end

local function login(rpcid, msg)
  local init = profile.init
  profile.device     = msg.device
  profile.openid     = msg.openid
  profile.sex        = msg.sex
  profile.name       = msg.name
  profile.imgurl = msg.imgurl
  profile.province   = msg.province
  profile.city       = msg.city

  profile.init = true
  send_message(rpcid, {
    result = "LOGIN_SUCCEED",
    new_player = not init,
  })

  -- 客户端使用id而不是uin
  profile.id = profile.uin
  profile.ip = info.addr
  send_msg("pushBasicPlayerInfo", profile)
  event.dispatchEvent(events.player_online)
end

M.beatTime = os.time()
local function heartBeat(rpcid, req)
  M.beatTime = os.time()
  return send_message(rpcid, {time = M.beatTime})
end

function M.heartBeatTime()
  return M.beatTime
end

function M.isinit()
  return profile.init
end

M.redis_key = profile_redis_key

function M.init_data()
  local ret = simple_copy_obj(profile_t)
  ret.uin = info.uin
  return ret
end

function M.data(data)
  profile = data
  for k,v in pairs(profile_t) do
    if profile[k] == nil then
      profile[k] = v
    end
  end
end

function M.modules(modules)
end

function M.register_event()
  event.addEventListener(events.profile_update, player_update)
end

function M.register_handler()
  register_msg_handler("login", login)
  register_msg_handler("heartBeat", heartBeat)
end

return M
