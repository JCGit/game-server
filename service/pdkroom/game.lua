local skynet  = require "skynet"
local machine = require "statemachine"
local card_constant = require "pdkroom.constant"
local lib = require "pdkroom.lib"
require "logger_api"()
local utils = require "utils"
local inspect = require "inspect"
local mongox = require "mongox"

local card_test = require "pdkroom.card_test"

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
G.goalCardCount = 5  
G.MAX_USER = nil  
G.SHOW_NUM_TYPE = false   -- 显示牌数
G.MUST_PLAY_TYPE = false   -- 管牌
G.prev_cue = {}
G.prev_cue_uin = nil
G.cache_cards = {} --缓存玩家打的牌，用于断线重连
G.max_round = nil  
G.round_result = {}
G.round_start_time = {}
G.cards = {}
G.current_play = 1

local initScore = 1000

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
    player.score = initScore
    player.scores = {}
    player.cards_count = 0 
    player.cards_countSet = {}
    player.bomb = 0
    player.total_bomb = 0
  end  
    
  G.WINNER = nil 
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
    player.bomb = 0
    player.min_card = 53  --最小方块牌, 有可能出现玩家手牌没有方块的情况
    player.single = nil
  end
  
  --INFO("ROOM_ID: ", db_room_id, " round: ", round_id)

  isVoteResume = nil
  --发牌逻辑
  local cards = {}
  G.cards = {}
  if not card_test.test then 
    cards = lib.shuffle_card(skynet.now(), CARD_MOUNT)
  else
    cards = card_test.card
  end
  local every_card_mount = 15
  G.current_play = 1

  for i, player in ipairs(players) do
    table.move(cards, (i - 1) * every_card_mount + 1, i * every_card_mount, 1, player.cards)
    table.sort(player.cards, function (a, b) 
      if a > b then
        return true
      end
    end)
  end

  if not G.WINNER then
    for k, v in ipairs(players) do 
      for i = #v.cards,1,-1  do
        if v.cards[i]%4 == 1 then
          v.min_card = v.cards[i]
          break
        end 
      end
    end
    G.WINNER = (players[1].min_card < players[2].min_card) and players[1] or players[2]   --方块小的先手
  end

  G.current_play = G.WINNER.profile.seatID

  for _,player in ipairs(players) do
    player.send_msg("pushRoundStart", {
      roundId = round_id,
      cards  = player.cards,
      banker = G.WINNER.uin
    })
  end

  notify_players("pushRoundStates", {pdk = { state = "PDK_ROUND_PLAY" }})
  G.prev_cue = {}
  G.prev_cue_uin = nil
  notify_players("pushPlayerOperate",  {pdk = { uin = G.WINNER.uin, type = "PDKPLAY", first = true}}) --第一手牌先手
  table.move(cards, #players * every_card_mount + 1, #cards, 1, G.cards)
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
  local score = 0 

  for _,v in ipairs(players) do
    if #v.cards > 0 then
      score = #v.cards
      for _,c in ipairs(v.cards) do
        if c == 54 then
          score = score + 9
        elseif c == 53 then
          score = score + 4
        end
      end
      if #v.cards >= 10 then
        score = 2 * score
      end
      if #v.cards == 15 then
        score = 56 
      end
      v.score = v.score - score
      table.insert(v.scores, - score)
    else
      G.WINNER = v
    end
  end
  table.insert(G.WINNER.scores, score)
  G.WINNER.score = G.WINNER.score + score

  for _,v in ipairs(players) do
     v.cards_count = v.cards_count + #v.cards
     table.insert(v.cards_countSet, #v.cards)
     table.insert(result, { uin = v.uin, score = v.scores[#v.scores], cards_count = #v.cards, bomb = v.bomb })
     v.total_bomb = v.total_bomb + v.bomb
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
  notify_players("pushRoundStates", {pdk = {state = "PDK_ROUND_ACCOUNTS"}})
  --推送结果
  notify_players("pushRoundStoped", {pdk = {playerresult = result}})

  if round_id == G.max_round then
    gfsm:game_over()
  end
end

local function gen_room_record(roomResult)
  local ret = mongox.safe_insert("room_record", {room_id = ROOM_ID, game_type = "PDK_GAME",  ts = G.room_start_time,
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
     if v.score > index  then
        winnerId = v.uin
        index = v.score
     end
     local winCount = 0
     local loseCount = 0
     for _, w in ipairs(v.cards_countSet) do
        if w == 0 then
          winCount = winCount + 1
        else
          loseCount = loseCount + 1
        end
     end
     
     table.insert(roomResult, {uin = v.uin,  score = v.score , name = v.profile.name, winCount = winCount, cardsCount = v.cards_count,
      loseCount = loseCount, bomb = v.total_bomb})
  end

  notify_players("pushRoomStop", {pdk = {playerAccounts = roomResult, winnerid = winnerId, gameTime = (os.time() - G.room_start_time) }})
  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  gen_room_record(roomResult)
end

--房间结束
function gfsm:ongame_stoped()
  game_stoped()
  skynet.send( ".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID) 
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
     notify_players("pushRoundPlayerState", {pdk = { uin = player.uin, state = "PDKREADY" }}, player)
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
  notify_players("pushPlayerOperate", {pdk = {
        type   = "PDKPLAY",
        uin    = players[G.current_play].profile.id,
        first  = (G.prev_cards.seatID == G.current_play)
      }}) 

  if G.prev_cards.seatID ~= G.current_play then
    local status, cue = lib.searchCard(G.prev_cards.card_type, G.prev_cards.count, 
          G.prev_cards.groups, players[G.current_play].cards)

    players[G.current_play].send_msg("pushCue", { pdk = { cueStatus = status, cue = cue }})
    G.prev_cue = cue
    G.prev_cue_uin = players[G.current_play].uin
    
    if G.MUST_PLAY_TYPE then
      if status ~= "ok" then
        notify_players("pushRoundPlayerState", {pdk = {
            uin = players[G.current_play].uin,
            state = "PDKNOCARD"
            }
          })
        G.current_play = next_index(G.current_play)
        return nextPlay()
      end
    end
    
  else
    G.prev_cue = {}
    G.prev_cue_uin = nil
  end
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

    if G.MUST_PLAY_TYPE and #cards == 0 then
      return "must_play"
    end

    if pcards.count ~= nil and #cards == 0 then
      G.current_play = next_index(G.current_play)
      return "ok", "NONE"
    end

    local last = (#player.cards == #cards) and (pcards.count == nil) --最后一手且先手
    local ret, card_type, groups = nil, nil, {}
    if G.prev_cue and G.prev_cue_uin ~= player.uin then
      for _,c in ipairs(G.prev_cue) do
        local index = nil
        for i = 1,#cards do
          if c.card_set[i] ~= cards[i] then
            index = nil
            break
          else
            index = i
            if i == #cards then
              break
            end
          end 
        end
        if index then
          ret = "ok"
          card_type = G.prev_cue[index].card_type
          groups = G.prev_cue[index].groups
          break
        end
      end
    end

    if not ret then
      ret, card_type, groups = lib.compare(cards, pcards.count, pcards.card_type,
                                               pcards.groups, last) 
    end
    if ret ~= "ok" then
      return ret
    end

    record_cache_cards(player, cards, card_type)

    if card_type == card_constant.CARD_TYPES.Boomb then
      player.bomb = player.bomb + 1
    end

    G.current_play = next_index(G.current_play)
    G.prev_cards = {
      seatID    = index,
      count     = #cards,
      card_type = card_type,
      groups    = groups,
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
  local remain = #player.cards
  notify_players("pushRoundPlayerState", {pdk = {
      uin = player.uin,
      state = #cards > 0 and "PDKPLAY" or "PDKSKIP"
      }
    })

  notify_players("pushPlayCards", {pdk = {
    uin         = player.profile.id,
    cards       = cards,
    cardType    = card_type,
    remainCards = remain,
  }})

  if remain == 1 then
    if not player.single  then
      notify_players("pushRoundPlayerState", { pdk = { uin = player.uin, state = "PDKSINGLE" } } )
      player.single = true
    end
  end

  if remain > 0 then
    nextPlay()
  else
    G.WINNER = player

    notify_players("pushShowCards", { uin = players[G.current_play].uin, cards = players[G.current_play].cards }, players[G.current_play])
    table.sort( G.cards, function (a, b) 
      if a > b then
        return true
      end 
    end)
    notify_players("pushShowCards", {cards = G.cards })
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

function game.start(pls, roomID, roomType, MAX_USER, showNumType, mustPlayType)
  G.room_start_time = os.time()
  ROOM_TYPE  = roomType
  G.MAX_USER = MAX_USER

  print("showNumType ------------ ", showNumType, mustPlayType)
  if showNumType == "SHOW" then
    G.SHOW_NUM_TYPE = true
  end
  if mustPlayType == "MUST" then
    G.MUST_PLAY_TYPE = true
  end

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

    player.send_msg("pushCache", { pdk = { 
      state = state,
      currentPlay  = current_play_uin,
      cacheInfo = cache_datas,
      readyDatas = ready,
      first = first,
      cards = player.cards,
      roundId = round_id,
      banker = G.WINNER.uin,
    }})
  end
end

function game.exit()
  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  game_stoped()
  skynet.sleep(100)
  skynet.send(".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID) 
end

function game.info()
  print("fsm->current -------", gfsm.current)
end

return game
