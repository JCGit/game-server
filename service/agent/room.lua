local skynet = require "skynet"
local mongox = require "mongox"

local send_message, send_status = send_message, send_status
local event, events = event, events

local profile_mod

local user_room, ROOM

local M = {}

M.redis_key = "user:room"

function M.init_data()
  user_room = nil
  return {}
end

function M.data(data)
  user_room = data
end

function M.modules(modules)
  profile_mod = modules.profile_mod
end

local function _get_room()
  if not ROOM and user_room.room_id then
    ROOM = skynet.call(".room_mgr", "lua", "LOOKUP_ROOM", user_room.room_id)
  end
  return ROOM
end

local function _clear_room_cache()
  ROOM = nil
  user_room.room_id = nil
  user_room.gameType = nil
end

local function openRoom(rpcid, msg)
  local send_status = send_status(rpcid)
  local _room = _get_room()
  if _room then
    local myself = skynet.call(_room, "lua", "PLAYER_STATE", info.uin)
    if myself.owner then
      return send_message(rpcid, {
        status = "ok",
        roomID = user_room.room_id
      })
    else
      return send_status("already_in_room")
    end
  end

  local COST_TBL = {
    FIVE_ROUNDS = 5,
    TEN_ROUNDS  = 10,
    TWN_ROUNDS  = 20,
  }

  local cost = COST_TBL[msg.roomType]
  if profile_mod.room_ticket() < cost then
    return send_status("lack_room_ticket")
  end

  user_room.room_id, ROOM = table.unpack(skynet.call(".room_mgr", "lua",
                                "OPEN_ROOM", info.uin, msg.gameType))
  user_room.gameType = msg.gameType

  skynet.call(ROOM, "lua", "SETTING", user_room.room_id, msg)

  return send_message(rpcid, {
    status = "ok",
    roomID = user_room.room_id
  })
end

local function enterRoom(rpcid, msg)
  local send_status = send_status(rpcid)
  local _room = _get_room()
  local roomID = msg.roomID

  local enter_room, gameType
  if _room then
    local myself = skynet.call(_room, "lua", "PLAYER_STATE", info.uin)
    if myself.owner or roomID == tostring(user_room.room_id) then
      enter_room = _room
      roomID = user_room.room_id
      gameType = user_room.gameType
    else
      return send_status("already_in_room")
    end
  else
    enter_room  = skynet.call(".room_mgr", "lua", "LOOKUP_ROOM", roomID)
    if not gameType then gameType = skynet.call(".room_mgr", "lua", "GAME_TYPE", roomID) end
    if not enter_room then
      return send_status("room_not_exist")
    end
  end
  local status = skynet.call(enter_room, "lua", "ENTER", skynet.self(), info.fd,
                          profile_mod.basic_profile(), info.uin, info.secret, msg.retry)

  if status == "ok" then
    user_room.room_id = roomID
    user_room.gameType = gameType
    ROOM = enter_room
  else
    return send_status(status)
  end
end

local function askRoomCache(rpcid, msg)
  local _room = _get_room()
  local ret = {}
  if _room then
    local myself = skynet.call(_room, "lua", "PLAYER_STATE", info.uin)
    ret.gameType = user_room.gameType
    ret.roomID = user_room.room_id
  end
  send_message(rpcid, ret)
end

local function leaveRoom(rpcid, msg)
  local _room = _get_room()
  local ret
  if _room then
    ret = skynet.call(_room, "lua", "LEAVE", info.uin)
  else
    ret = "ok"
  end
  send_message(rpcid, {status = ret})
end

function M.KICK_OUT_ROOM(source_room)
  assert(ROOM == source_room)
  _clear_room_cache()
end

local function destoryRoom(rpcid, msg)
  local send_status = send_status(rpcid)
  local _room = _get_room()
  local ret
  if _room then
    ret = skynet.call(_room, "lua", "DESTORY_ROOM", info.uin)
  else
    ret = "ok"
  end
  send_status(ret)
end

local function request_room(rpcid, ...)
  local _room = _get_room()
  local status
  if _room then
    status = skynet.call(_room, "lua", ...)
  else
    status = "not_in_room"
  end
  if status ~= "ok" then
    send_message(rpcid, {status = status} )
  end
end

register_msg_handler("playerReady", function(rpcid, msg)
  request_room(rpcid, "PLAYER_READY", info.uin)
end)

register_msg_handler("startVote", function(rpcid, msg)
  request_room(rpcid, "START_VOTE", info.uin)
end)

register_msg_handler("vote", function(rpcid, msg)
  request_room(rpcid, "VOTE", info.uin, msg.agree)
end)


register_msg_handler("gameReady", function(rpcid, msg)
  request_room(rpcid, "GAME_READY")
end)

register_msg_handler("voice", function(rpcid, msg)
  request_room(rpcid, "VOICE", msg.data, msg.uin)
end)

 register_msg_handler("fastNews", function (rpcid, msg)
   request_room(rpcid, "FastNews", msg)
 end)

-- dn相关协议
register_msg_handler("bet", function(rpcid, msg)
 request_room(rpcid, "BET", msg)
end)

register_msg_handler("roundStop", function (rpcid, msg)
 request_room(rpcid, "RoundStop", msg)
end)

-- pdk相关协议
register_msg_handler("playCards", function(rpcid, msg)
 request_room(rpcid, "PlayCards", msg.cards)
end)

register_msg_handler("rob", function (rpcid, msg)
   request_room(rpcid, "Rob", msg)
 end)

function M.register_handler()
  register_msg_handler("openRoom", openRoom)
  register_msg_handler("enterRoom", enterRoom)
  register_msg_handler("askRoomCache", askRoomCache)
  register_msg_handler("leaveRoom", leaveRoom)
  register_msg_handler("destoryRoom", destoryRoom)
end

local function on_player_offline () 
  if ROOM then
    print("---- player offline ---------- ", info.uin)
    skynet.call(ROOM, "lua", "OFFLINE", info.uin)
  end
end

function M.register_event ()
  event.addEventListener(events.player_offline, on_player_offline)
end

return M
