local skynet  = require "skynet"
local machine = require "statemachine"
local card_constant = require "qgwroom.constant"
local lib = require "qgwroom.lib"
require "logger_api"()
local utils = require "utils"
local inspect = require "inspect"
local mongox = require "mongox"


local CARD_MOUNT = card_constant.CARD_MOUNT
local ROOM_ID, ROOM_TYPE

local players
local round_id
local isVoteResume = nil
local isTest = false

local G = {} --一些模块内公用数据
G.prev_cards = {}  --上一手牌
G.ROOM_STATE = nil 
G.WINNER = nil  --上一局赢家
G.room_start_time = nil 
G.MAX_USER = nil  
G.prev_cue = {}
G.prev_cue_uin = nil
G.cache_cards = {} --缓存玩家打的牌，用于断线重连
G.max_round = nil  
G.round_result = {}
G.round_start_time = {}
G.cards = {}
G.current_play = 1
G.first = nil 
G.Score = 0  --桌面分数
G.every_card_mount = 5


local initScore = 0

local gfsm = machine.create({
  initial = 'game_none',
  events = {
    {  name  =  'startup',        from  =  'game_none',         to  =  'game_started'      },
    {  name  =  'go_next_round',  from  =  'game_started',      to  =  'round_started'     },
    {  name  =  'shuffle_card',   from  =  'round_started',     to  =  'round_running'     },
    {  name  =  'suspend',        from  =  'round_running',     to  =  'round_suspending'  },
    {  name  =  'resume',         from  =  'round_suspending',  to  =  'round_running'     },
    {  name  =  'round_over',     from  =  'round_running',     to  =  'round_stoped'      },
    {  name  =  'go_next_round',  from  =  'round_stoped',      to  =  'round_started'     },
    {  name  =  'game_over',      from  =  'round_stoped',      to  =  'game_stoped'       },
  }
})

-- 回复给agent状态是ok
local function response_ok(player, msgid_name)
  skynet.response()(true, "ok")
  player.send_msg(msgid_name, {status="ok"})
end

local function notify_players(msgid_name, msg, player)
  for _, v in ipairs(players) do
    if not player then 
       v.send_msg(msgid_name, msg)
    elseif player.uin ~= v.uin then
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

local check_time = 30
local function check_heart()
    for _,v in ipairs(players) do
        if not v.offline then
          local time = skynet.call(v.agent, "lua", "profile_mod", "heartBeatTime")
          time = os.time() - time
          if time >= 120 then
            local room = skynet.call(".room_mgr", "lua", "LOOKUP_ROOM", ROOM_ID)
            skynet.call(room, "lua", "OFFLINE", v.uin)
          end
       end
    end
    return skynet.timeout(check_time*100, check_heart)
end

function gfsm:onstatechange(event, from, to)
  WARN("game state change: ", event, from, to)
end

function gfsm:ongame_started(event, from, to, pls)
  print("ongame_started", event, from, to, pls, inspect(players))
  players = pls

  for _, player in ipairs(players) do
    player.total_score = initScore  --总积分变化
    player.score = initScore   --单局积分
    player.scores = {}
  end  
    
  for _, v in ipairs(players) do
    if v.profile.owner then
      local COST_TBL = {
        FIVE_ROUNDS = 1,
        TEN_ROUNDS = 2,
        TWN_ROUNDS = 4,
      }
      skynet.call(v.agent, "lua", "profile_mod", "room_ticket", -COST_TBL[ROOM_TYPE])
      break
    end
  end
  skynet.timeout(check_time*100, check_heart) 
  gfsm:go_next_round()
end

--计算结果
--local current_play      -- 当前出牌用户顺序
-- 一局开始洗牌发牌
function gfsm:onround_started()
  --重置相关数据
  G.cache_cards = {}

  G.round_start_time[round_id] = os.time()

  -- 增加局数
  round_id = round_id + 1
  for _, player in ipairs(players) do
    player.cards = {}      -- 初始化牌列表  
    player.score = 0
  end
  G.WINNER = nil 
  G.score = 0 

  isVoteResume = nil
  --发牌逻辑
  local cards = {}
  G.cards = {}
  cards = lib.shuffle_card(skynet.now(), CARD_MOUNT)

  for i, player in ipairs(players) do
    table.move(cards, (i - 1) * G.every_card_mount + 1, i * G.every_card_mount, 1, player.cards)
    table.sort(player.cards, function (a, b) 
      if a > b then
        return true
      end
    end)
  end
  table.move(cards, #players * G.every_card_mount + 1, #cards, 1, G.cards)

  for k, v in ipairs(players) do 
    if not G.first then
      G.first = v
    else
      if G.first.cards[#G.first.cards] > v.cards[#v.cards] then
        G.first = v
      end
    end  
  end

  G.current_play = G.first.profile.seatID

  for _,player in ipairs(players) do
    player.send_msg("pushRoundStart", {
      roundId = round_id,
      cards  = player.cards,
      banker = G.first.uin
    })
  end

  notify_players("pushRoundStates", {qgw = { state = "QGW_ROUND_PLAY" }})
  G.prev_cue = {}
  G.prev_cue_uin = nil
  notify_players("pushPlayerOperate",  {qgw = { uin = G.first.uin, type = "QGW_PLAY", first = true}}) --第一手牌先手

  return self:shuffle_card()   --两人模式直接开始
end

--下一个玩家
local function next_index(pre)
  local index = pre + 1
  index = (index > G.MAX_USER) and 1 or index
  return index
end

local function dealRoundResult()
  local result ={}
  for _,v in ipairs (players) do 
    table.insert(result, { uin = v.uin, score = v.score})
    table.insert(v.scores, v.score)
    v.total_score = v.total_score + v.score
  end
  G.round_result[round_id] = {}
  G.round_result[round_id].result = result
  G.round_result[round_id].ts = G.round_start_time[round_id]
  return result
end

-- 一局结束，可能再在多种情况下结束，需要分类讨论
function gfsm:onround_stoped(event, from, to)
  G.ROOM_STATE ="ACCOUNTS"
  local result = dealRoundResult()

  -- 清除玩家的准备状态，下次开始游戏需要重新准备
  for _, p in ipairs(players) do
    p.ready = false
  end
  notify_players("pushRoundStates", {qgw = {state = "QGW_ROUND_ACCOUNTS"}})
  --推送结果
  notify_players("pushRoundStoped", {qgw = {result = result}})

  if round_id == G.max_round then
    gfsm:game_over()
  end
end

local function gen_room_record(roomResult)
  local ret = mongox.safe_insert("room_record", {room_id = ROOM_ID, game_type = "QGW_GAME",  ts = G.room_start_time,
  room_result = roomResult, round_result = G.round_result})

  -- ts 等于房间开始时间
  for _, v in ipairs(players) do
    mongox.safe_insert("player_room_record", { uin = v.uin, room_db_id = ret._id, ts = G.room_start_time })
  end
end

local function game_stoped()
  local winnerId
  local roomResult = {}
  local index = 0
  for _, v in ipairs(players) do
     if v.total_score > index  then
        winnerId = v.uin
        index = v.total_score
     end
     local winCount = 0
     local loseCount = 0
     for _, w in ipairs(v.score) do
        if w > 0 then
          winCount = winCount + 1
        else
          loseCount = loseCount + 1
        end
     end
     table.insert(roomResult, {uin = v.uin,  score = v.total_score , name = v.profile.name, winCount = winCount, loseCount = loseCount })
  end

  notify_players("pushRoomStop", {qgw = {playerAccounts = roomResult, winnerid = winnerId, gameTime = (os.time() - G.room_start_time) }})
  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  gen_room_record(roomResult)
end

--房间结束
function gfsm:ongame_stoped()
  game_stoped()
  skynet.sleep(3*100)
  skynet.send( ".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID ) 
end

local command = {}

function command.GAME_READY(source)
  if gfsm:cannot("go_next_round") then
    return gfsm.current
  end
  local player = find_player(source)
  player.ready = true
  response_ok(player, "gameReady")
  if round_id ~= 0 then
     notify_players("pushRoundPlayerState", {qgw = { uin = player.uin, state = "QGW_READY" }})
  end

  local readyindex = true
  for _, v in ipairs(players) do
    if not v.ready then
      readyindex = false
    end
  end
  if readyindex and G.MAX_USER > 1 then
     gfsm:go_next_round()
  end
end

local function nextPlay()
  print("nextPlay",G.current_play)
  --先广播谁操作
 
  if G.prev_cards.seatID ~= G.current_play then
    local status, cue = lib.searchCard(players[G.current_play].cards, G.prev_cards.card_type, G.prev_cards.cards)

    players[G.current_play].send_msg("pushCue", { qgw = { cueStatus = status, cue = cue }})
    G.prev_cue = cue
    G.prev_cue_uin = players[G.current_play].uin
   
  else
    G.prev_cue = {}
    G.prev_cue_uin = nil

    if G.score > 0 then 
      --获得桌面积分
      notify_players("pushScore", { isDesktop = false, score = G.score, uin = players[G.current_play].uin })
      G.score = 0 
      notify_players("pushScore", { isDesktop = true, score = G.score })  --桌面积分清零
    end
    --补牌
    for _,v in ipairs(players) do
      local cards = {}
      if #v.cards < G.every_card_mount then
        local num = ( G.every_card_mount - #v.cards < #G.cards ) and ( G.every_card_mount - #v.cards ) or #G.cards
        table.move(G.cards, 1, num, 1, cards)
        v.send_msg("pushCards", { uin = v.uin, cards = cards })
        table.move(cards, 1, #cards, #v.cards + 1, v.cards)
        print(">>>>>>>>>>>>>",inspect(v.cards))
      end
    end

  end

  notify_players("pushPlayerOperate", {qgw = {
        type   = "QGW_PLAY",
        uin    = players[G.current_play].profile.id,
        first  = (G.prev_cards.seatID == G.current_play)
      }}) 

end

local function play_card(player, cards)
  local function play(player, cards)
    if not lib.contains(player.cards, cards) then
      return "not_your_cards"
    end

    --缓存玩家出牌
    local function record_cache_cards(player, cards, card_type)
      G.cache_cards[player.profile.seatID] = {cards = cards, card_type = card_type}
    end

    local index = player.profile.seatID
    local pcards = {}
    if G.prev_cards.seatID ~= index then
      pcards = G.prev_cards
    end

    if pcards.count == nil and #cards == 0 then
      return "first_must_play"
    end

    --一回合先手时，重置缓存信息
    if pcards.count == nil then
      G.cache_cards = {}
    end 

    if pcards.count ~= nil and #cards == 0 then
      G.current_play = next_index(G.current_play)
      return "ok", "NONE"
    end

    local ret, card_type = nil, nil
    if G.prev_cue and G.prev_cue_uin ~= player.uin then
      for _,c in ipairs (G.prev_cue) do
        if c == cards then
          ret = "ok"
          card_type = G.prevCardType
        end
      end
    end

    if not ret then
      ret, card_type = lib.compare(cards, pcards.card_type, pcards.cards)
    end
    if ret ~= "ok" then
      return ret
    end

    record_cache_cards(player, cards, card_type)

    G.current_play = next_index(G.current_play)
    G.prev_cards = {
      seatID    = index,
      count     = #cards,
      card_type = card_type,
      cards     = cards,
    }

    lib.remove_sublist(player.cards, cards)
    return "ok", card_type
  end

  local ret, card_type = play(player, cards)
  print("play card card_type :", card_type)
  if ret ~= "ok" then
    return ret
  end

  response_ok(player, "playCards")
  local mScore = lib.getScore(cards)
  if mScore > 0 then
    notify_players("pushScore", { isDesktop = true, score = mScore })
    G.score = G.score + mScore
  end
 
  local remain = #player.cards
  notify_players("pushRoundPlayerState", {qgw = {
      uin = player.uin,
      state = #cards > 0 and "QGW_PLAY" or "QGW_SKIP"
      }
    })

  notify_players("pushPlayCards", {qgw = {
    uin         = player.profile.id,
    cards       = cards,
    cardType    = card_type,
    remainCards = remain,
  }})

  if remain > 0 then
    nextPlay()
  elseif #G.cards == 0 and remain == 0 then 
    for _,v in ipairs(players) do
      if not G.WINNER then
        G.WINNER = v
      elseif v.score > G.WINNER.score then
        G.WINNER = v
      end
    end
    
    for _,v in ipairs(players) do
      if v.uin ~= G.WINNER.uin then
        notify_players("pushShowCards", { uin = v.uin, cards = v.cards }, v)
      end
    end

    gfsm:round_over(player)
  end
end

function command.PlayCards(source, cards)
  local player = find_player(source)
  if gfsm:is("round_running") then
    if G.current_play ~= player.profile.seatID then
      return "not_your_operate"
    else   
      return play_card(player, cards)
    end
  end
end

local game = {}
function game.command(cmd, source, ...)
  local f = command[cmd]
  if not f then
    return false, "Unknown command"
  end
  return xpcall(f, debug.traceback, source, ...)
end

function game.start(pls, roomID, roomType, MAX_USER)
  G.room_start_time = os.time()
  ROOM_TYPE  = roomType
  G.MAX_USER = MAX_USER

  ROOM_ID = roomID
  --局数
  if ROOM_TYPE == "FIVE_ROUNDS" then 
    G.max_round = 5 
  elseif ROOM_TYPE == "TEN_ROUNDS" then
    G.max_round = 10
  else
    G.max_round = 20
  end

  G.max_round = 2

  round_id = 0
  gfsm:startup(pls)
  return gfsm
end

--房间内挂起
function game.suspend()
  -- body
  if gfsm:is("round_running") then
    gfsm:suspend()
  else
    return gfsm.current
  end
end

--从挂起切回继续
function game.resume()
  if gfsm:is("round_suspending") then
     isVoteResume = true
     gfsm:resume()
  else
    return gfsm.current
  end
end

--针对重连用户的数据推送
function game.push_cache(player)
  if not player then return end

  INFO("offline deal : ", player.uin,  gfsm.current)

  local state, current_play_uin, ready, first
  if gfsm:is("round_running") or gfsm:is("round_suspending") then
    state = "PLAY_CARDS"
    current_play_uin = players[G.current_play].uin

    print("seatId -------------- ", G.prev_cards.seatID, G.current_play)
    first = G.prev_cards.seatID and G.prev_cards.seatID == G.current_play or player.profile.seatID == G.current_play 

  elseif gfsm:is("game_started") or gfsm:is("round_stoped") then
    if not player.game_ready then
      state = "READY"
      ready = player.game_ready
    end
  elseif gfsm:is("game_stoped") then
    return "game_stoped"
  end

  if player and state then
    local cache_datas
    if state ~= "READY" then
      print("cache --- cards --- ", player.profile.seatID)
      utils.var_dump(G.cache_cards)
      cache_datas = {}
      for _, v in pairs(players) do
        local remain
        if G.SHOW_NUM_TYPE then
          remain = #v.cards
        end
        table.insert(cache_datas, {
          uin = v.uin,
          remain = remain,
          cards = G.cache_cards[v.profile.seatID] and G.cache_cards[v.profile.seatID].cards or nil,
          cardType = G.cache_cards[v.profile.seatID] and G.cache_cards[v.profile.seatID].card_type or nil,
          score = v.score
        })
      end
      if player.profile.seatID == G.current_play then
          cache_datas[player.profile.seatID].cards = nil
          cache_datas[player.profile.seatID].cardType = nil
      end
    end

    player.send_msg("pushCache", { qgw = { 
      state = state,
      currentPlay  = current_play_uin,
      cacheInfo = cache_datas,
      readyDatas = ready,
      first = first,
      cards = player.cards,
      roundId = round_id,
      desktopScore = G.score
    }})
  end
end

function game.exit()
  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  game_stoped()
  skynet.sleep(1000)
  skynet.send(".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID) 
end

function game.info()
  print("fsm->current -------", gfsm.current)
end

return game
