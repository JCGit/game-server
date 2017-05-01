local skynet  = require "skynet"
local message = require "message"
local machine = require "statemachine"
local game    = require "tegroom.game"
local json   = require "cjson"
local inspect = require "inspect"
require "logger_api"()

local command = {}

local EMPTY = {}
local players = {}
local MAX_USER = 3


local ROOM_ID, ROOM_OWNER = ...
ROOM_OWNER = tonumber(ROOM_OWNER)
local ROOM_TYPE
local showType

local rfsm = machine.create({
  initial = 'room_created',
  events = {
    { name = 'init'       , from = 'room_created' , to = 'room_waiting' } ,
    { name = 'ready'      , from = 'room_waiting' , to = 'room_running' } ,
    { name = 'start_vote' , from = 'room_running' , to = 'room_voteing' } ,
    { name = 'resume'     , from = 'room_voteing' , to = 'room_running' } ,
    { name = 'exit'       , from = '*'            , to = 'room_exiting' } ,
  }
})

local function online_users()
  local ret = {}
  for _, v in ipairs(players) do
    if v ~= EMPTY then
      table.insert(ret, v)
    end
  end
  return ret
end

local function push_offline_cache(player)
   if rfsm:is('room_voteing') then
      local index = true
      if votes then
        for _,v in ipairs(votes) do
            if v.uin == player.uin then
              index = false
            end
        end
      end
      if index then 
         RESULT_TIME = RESULT_TIME - ( os.time() - VOTE_TIME )  --剩下的时间                        
         player.send_msg("pushVote", {
                  uin         = VOTES_STARTER or nil,
                  resultTime = RESULT_TIME})
      end
      game.push_cache(player)
  elseif rfsm:is('room_waiting') then
    local readyDatas = {}
    for _, v in ipairs(online_users()) do
      table.insert(readyDatas, {uin = v.uin, ready = v.ready})
    end
    player.send_msg("pushCache", {teg = {state = "READY",  readyDatas = readyDatas}})
  elseif rfsm:is("room_running") then
    game.push_cache(player)
  else
    return rfsm.current
  end
end

-- 回复给agent状态是ok，当agent收到ok时不会把状态码发回给客户端
-- 而是由当前服务发回ok状态给客户端，这是为了保证与后面的消息时序一致
local function response_ok(player, msgid_name)
  skynet.response()(true, "ok")
  player.send_msg(msgid_name, {status="ok"})
end

local function notify_players(msgid_name, msg, filter_uin)
  for _, v in ipairs(players) do
    if v ~= EMPTY and v.uin ~= filter_uin then
      v.send_msg(msgid_name, msg)
    end
  end
end

local function find_player(agent)
  for _, v in ipairs(players) do
    if v.agent == agent then
      return v
    end
  end
end

local function findPlayerByUin(uin)
  for _, v in ipairs(players) do
    if v.uin == uin then
      return v
    end
  end
end

local function agent_response(ret)
  skynet.response()(true, ret)
end

function rfsm:onstatechange(event, from, to)
  WARN("room state change: ", event, from, to)
end

function rfsm:onready()
  for _, v in ipairs(players) do
    if v.uin then
      v.send_msg("pushRoomState", {
        state = "ROOM_READY_GAME"
      })
    end
  end
  game.start(players, ROOM_ID, ROOM_TYPE, MAX_USER, showType)
end

local function exit()
  print("exit -- state -- ", rfsm.current)

  skynet.sleep(60 * 100)
  print("exit  finish ")
  skynet.exit()
end


function rfsm:onexit()
  for i, v in ipairs(online_users()) do
    players[v.profile.seatID] = nil
    skynet.send(v.agent, "lua", "room_mod", "KICK_OUT_ROOM", skynet.self())
    v.send_msg("pushRoomState", {state="ROOM_DESTORY"})
  end

  --通过skynet.fork 先状态机先跳转到 room_exiting 状态
  skynet.fork(exit)
end


local VOTE_TIME   = 30
local RESULT_TIME = 80
local votes
function rfsm:onstart_vote(event, from, to, starter)
  votes = {}
  notify_players("pushVote", {
    uin         = starter,
    resultTime = RESULT_TIME,
  })
  game.suspend()
  skynet.timeout(RESULT_TIME * 100, function()
    if rfsm:is("room_voteing") then
      notify_players("pushVoteEnd", {status = 1})   --默认解散
      game.exit()
    end
  end)
end

local NORET = {}

function command.SETTING(source, room_id, msg)
  assert(rfsm:is('room_created'))
  rfsm:init()
  ROOM_TYPE  = assert(msg.roomType)

  local rules = {}
  if msg.rules then
    rules = json.decode(msg.rules)
    showType = rules.showType
    --mustType = rules.mustType
  end
  
  ROOM_ID  = room_id
  return true
end

function command.EXIT()
  if rfsm:is("room_exiting") then
    return NORET
  end

  WARN(rfsm.current, " will exit")
  rfsm:exit()
  return NORET
end

function command.OFFLINE(_source, uin)
  local player = findPlayerByUin(uin)
  if not player then return end
  player.offline = true
  notify_players("pushPlayerState", {
    state = "PLAYER_STATE_OFFLINE",
    uin    = uin,
    }, player.uin)
end

local function agentStartGame()
  local readyindex = true
  for _, v in ipairs(players) do
    if not v.ready then
      readyindex = false
    end
  end
  if readyindex and #players == MAX_USER then
    rfsm:ready()
  end
end

function command.ENTER(source, agent, fd, profile, uin, secret, retry)
  if rfsm:is("room_exiting") then
    return "room_exiting"
  end

  -- 进房间有可能是重登，fd, secret 等等都变了
  local function refresh(player, insert_seat)
    profile.seatID = insert_seat
    profile.owner   = (uin == tonumber(ROOM_OWNER))
    profile.id      = uin
    profile.openid  = profile.openid
    player.agent   = agent
    player.uin     = uin
    player.profile = profile
    player.send_client_msg = message.mk_send_message(fd, secret, uin)
    player.send_msg = function (msgid_name, msg)
      print("msgid_name", msgid_name)
      local msgid = assert(message.MI[msgid_name], 'unknown msgid')
      if player.uin then return player.send_client_msg(msgid, msg)end
    end
  end

  local function response_client_ok(player)
    local special = json.encode({showType = showType})
    player.send_msg("enterRoom", {
      status    = "ok",
      seatID   = player.profile.seatID,
      roomID   = ROOM_ID,
      special  = special,
      gameType = "TEG_GAME",
      roomType = ROOM_TYPE,
    })

    local profiles = {}
    for _, v in ipairs(online_users()) do
      --添加offline的标志，这样写不是很好
      --v.profile.offline = v.offline
      table.insert(profiles, v.profile)
    end
    player.send_msg("pushPlayers", {players = profiles})
  end

  for seat, player in ipairs(players) do
    if player.uin == uin then
      refresh(player, seat)
      notify_players("pushPlayerState", {
        state = "PLAYER_STATE_SIT",
        uin    = uin,
      }, uin)

      response_client_ok(player)
        --对重连玩家发送缓存消息
      if player.offline or retry then
        player.offline = false
       
        --推送玩家数据
        INFO("push offline cache")
        push_offline_cache(player)
      end
      return "ok"
    end
  end

  if #players == MAX_USER then
    return "room_full"
  end
  local insert_seat= #players+1
  if not rfsm:is("room_waiting") then
    return rfsm.current
  end
 
  local player = {}
  refresh(player, insert_seat)
  notify_players("pushPlayers", {players = {profile}})
  
  players[insert_seat] = player
  response_client_ok(player)
  agent_response("ok")
  for _,v in ipairs(players) do
    if v.ready then
        player.send_msg("pushRoundPlayerState", {teg = {
            uin = v.uin,
            state = "TEG_READY",
        }})
    end
  end
  agentStartGame() 
  return NORET
end

function command.PLAYER_STATE(source, uin)
  if rfsm:is("room_exiting") then
    return EMPTY
  end

  for _, player in ipairs(players) do
    if player.uin == uin then
      return player.profile
    end
  end
  return EMPTY
end

function command.LEAVE(source, uin)
  if rfsm:is("room_exiting") then
    return "ok"
  end
  if not rfsm:is("room_waiting") then
    return rfsm.current
  end

  local player
  for i, v in ipairs(players) do
    if v.uin == uin and not v.uin ~= ROOM_OWNER then
      if uin == ROOM_OWNER then
        notify_players("pushPlayerState", {
          state = "PLAYER_STATE_TEMP_LEFT",
          uin    = uin,
        }, uin)
        return "ok"
      end
      player = v
      players[i] = EMPTY
      break
    end
  end
  if player then
    for i, v in ipairs(online_users()) do
      v.send_msg("pushPlayerState", {
        state = "PLAYER_STATE_EXIT",
        uin    = uin,
      })
    end
    skynet.send(player.agent, "lua", "room_mod", "KICK_OUT_ROOM", skynet.self())
  end
  return "ok"
end

function command.DESTORY_ROOM(source, uin)
  if not rfsm:is("room_waiting") then
    return rfsm.current
  end
  if uin ~= ROOM_OWNER then
    return "not_room_owner"
  end
  skynet.send(".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID)
  return NORET
end

function command.START_VOTE(source, uin)
  local player = find_player(source)
  if rfsm:is('room_waiting') then
     if uin == ROOM_OWNER then
        command.DESTORY_ROOM(source, uin)
        notify_players("startVote", {status = "room_exiting"}, uin)
       return "room_exiting"
     else
       return "not_room_owner"
     end
  end
  if rfsm:is('room_voteing') then 
     return "room_voteing"
  end
  --agent_response("ok")
  response_ok(player, "startVote")
  rfsm:start_vote(uin)
  command.VOTE(source, uin, true, "inner")
  return NORET
end

function command.VOTE(source, uin, agree, inner)
  if not rfsm:is('room_voteing') then
    return rfsm.current
  end
  for _, v in ipairs(votes) do
    if v.uin == uin then
      return "room_have_voted"
    end
  end
  table.insert(votes, {uin = uin, agree = agree})
  if not inner then
    agent_response("ok")
  end
  local count = 0
  for _,v in ipairs(votes) do
     if v.agree then
        count = count + 1
     end
  end

  if count >= math.ceil(#players/2) then 
     notify_players("pushVoteEnd", {status = 1, votes = votes})
     game.exit()
  elseif #votes - count >= math.ceil(#players/2) then
     notify_players("pushVoteEnd", {status = 2, votes = votes})
     rfsm:resume()
     game.resume()
  end
  return NORET
end

function command.PLAYER_READY(source)
  local player = find_player(source)
  if not rfsm:is("room_waiting") then
    WARN("player ready at " .. rfsm.current)
    response_ok(player, "playerReady")
    return NORET
  end

  if player.ready then
    response_ok(player, "playerReady")
    return NORET
  end
  player.ready = true
  response_ok(player, "playerReady")
  notify_players("pushRoundPlayerState", {teg = { uin = player.uin, state = "TEG_READY" }})
  
  agentStartGame() 
  return NORET 
end

function command.VOICE(source, data, uin)
  local player = find_player(source)
  response_ok(player, "voice")

  notify_players("pushVoice", {uin=uin, data=data}, uin)
  return NORET
end

function command.FastNews(source, msg)
  local player = find_player(source)
  response_ok(player, "fastNews")

  notify_players("pushFastNews", { uin = player.uin, id = msg.id }, player.uin)  
  return NORET
end

local ROOM_MAX_WAIT_TIME = 30*60*100
local function check_wait_exit()
  if rfsm:is("room_waiting") then
    skynet.send(".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID)
  end
end

skynet.info_func(function ()
    game.info()
end)

skynet.start(function()
  skynet.timeout(ROOM_MAX_WAIT_TIME, check_wait_exit)
  skynet.dispatch("lua", function(_, source, cmd, ...)
    local f = command[cmd]
    if f then
      local ok, ret = xpcall(f, debug.traceback, source, ...)
      if not ok then
        skynet.error(string.format("Handle message(%s) failed: %s", cmd, ret))
        return skynet.ret(skynet.pack {"Call failed"})
      elseif ret ~= NORET then
        return skynet.ret(skynet.pack(ret))
      end
    else
      local ok, ret = game.command(cmd, source, ...)
      if not ok then
        skynet.error(string.format("Handle message(%s) failed: %s", cmd, ret))
        return skynet.ret(skynet.pack {"Call failed"})
      elseif ret ~= nil then
        return skynet.ret(skynet.pack(ret))
      end
    end
  end)
end)
