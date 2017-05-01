local skynet  = require "skynet"
local machine = require "statemachine"
local card_constant = require "tegroom.constant"
local lib = require "tegroom.lib"
require "logger_api"()
local utils = require "utils"
local inspect = require "inspect"
local mongox = require "mongox"

local card_test = require "tegroom.card_test"

local CARD_MOUNT = card_constant.CARD_MOUNT
local ROOM_ID, ROOM_TYPE, ROOM_OWNER, SHOW_NUM_TYPE

local players
local max_round


local G = {} --一些模块内公用数据
G.prev_cards = {}  --上一手牌
G.ROOM_STATE = nil 
G.winMode = nil     --叫倍数赢的模式
G.dealer = nil  --庄家
G.room_start_time = nil
G.rob = 1 
G.MAX_USER = nil   
G.prev_cue = {}
G.prev_cue_uin = nil
G.cache_cards = {} --缓存玩家打的牌，用于断线重连
G.round_id = 1
G.canOper = {}  
G.isVoteResume = nil
G.initScore = 1000
G.current_play = 1
G.round_start_time = {}
G.round_result = {}
G.first_player = nil

G.thecard = {}    --底牌

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
    {  name  =  'round_flow',     from  =  'round_started',     to  =  'round_started'     },
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
  players = pls
  for _, player in ipairs(players) do
    player.score = G.initScore
    player.scores = {}
    player.total_bomb = 0
    if player.profile.owner then
       ROOM_OWNER = player   
    end
  end   

  for _, v in ipairs(players) do
    if v.profile.owner then
      local COST_TBL = {
        FIVE_ROUNDS = 1,
        TEN_ROUNDS = 2,
        TWN_ROUNDS = 4,
      }
      local ret = skynet.call(v.agent, "lua", "profile_mod", "room_ticket",
                            -COST_TBL[ROOM_TYPE])
      break
    end
  end
  gfsm:go_next_round()
end

--计算结果
--local current_play      -- 当前出牌用户顺序
local cache_record = {}  -- 缓存的玩家牌，用于断线重连

-- 一局开始洗牌发牌
function gfsm:onround_started()
  -- 初始化状态
  G.thecards = {}
  cache_record = {}
  -- 增加局数
  G.round_id = G.round_id + 1
  for i, player in ipairs(players) do
    player.cards = {}      -- 初始化牌列表  
    player.bomb = 0
    player.rob = nil
    player.single = nil
  end
  
  G.round_start_time[G.round_id] = os.time()

  INFO("ROOM_ID: ", ROOM_ID, " round: ", G.round_id)
  
  G.canOper = { 3, 4, 5 }
  G.dealer = nil
  G.winMode = nil
  G.isVoteResume = nil
  G.prev_cards = {}
  G.first_player = nil 

  --发牌逻辑
  if not card_test.test then 
    cards = lib.shuffle_card(skynet.now(), CARD_MOUNT)
  else
    cards = card_test.card
  end
  local every_card_mount = 17

  local thecardA = math.random(29, 32)   --随机一张2与10当底牌
  local thecardB = math.random(49, 52)
  for i =#cards, 1, -1 do
    if cards[i] == thecardA or cards[i] == thecardB or cards[i] == 54 then
      table.insert(G.thecards, cards[i])
      table.remove(cards, i)
    end
  end
  
  table.sort(G.thecards, function (a, b)        
      if a > b then
        return true
      end
    end)
  
  for i, player in ipairs(players) do
    table.move(cards, (i - 1) * every_card_mount + 1, i * every_card_mount, 1, player.cards)
    table.sort(player.cards, function (a, b)
      if a > b then
        return true
      end
    end)
  end
  
  for _,v in ipairs(players) do
     for k,c in ipairs(v.cards) do
       if c == 1 then
         G.current_play = v.profile.seatID
         G.dealer = v 
         G.first_player = v
         v.rob = 1
         G.rob = 1
       end
     end
  end

  for _,v in ipairs (players) do
    v.send_msg("pushRoundStart", {
      roundId = G.round_id,
      cards  = v.cards,
      banker = G.first_player.uin,
    })
  end

  notify_players("pushShowCards", { cards = G.thecards })   --广播三张底牌

  G.ROOM_STATE = "ROB"
  notify_players("pushRoundStates", {teg = {state = "TEG_ROUND_ROB" }})
  notify_players("pushPlayerOperate", { teg = { 
                        uin = players[G.current_play].uin, 
                        type = "TEG_ROB", 
                        canOper = G.canOper }})

end

--下一个玩家
local function next_index(pre)
  local index = pre + 1
  index = (index > G.MAX_USER) and 1 or index
  return index
end


local function dealPlayerResult()
  local result ={}
  local score = 0 
  if G.winMode =="SPRING" then
    local index = true
    for _,v in ipairs(players) do
      if v.uin ~= G.dealer.uin then
        if #v.cards ~= 17 then
          index = false
        end
      end
    end
    for _,v in ipairs(players) do
      if v.uin ~= G.dealer.uin then 
        score = (G.WINNER.uin == G.dealer.uin and index) and - G.dealer.rob or 
                        G.dealer.rob 
        v.score = v.score +score
        table.insert(v.scores, score)
      end
    end 
    score =  (G.WINNER.uin == G.dealer.uin and index) and  
                            2 * G.dealer.rob  or  -2 * G.dealer.rob
    G.dealer.score = G.dealer.score + score
    table.insert(G.dealer.scores, score)
  elseif G.winMode == "OTHER" then 
    for _,v in ipairs(players) do
      if v.uin ~= G.dealer.uin then
        score = (G.WINNER.uin == G.dealer.uin) and -G.dealer.rob 
                        or G.dealer.rob
        v.score =  v.score + score
        table.insert(v.scores, score)
      end
    end
    score = (G.WINNER.uin == G.dealer.uin) and  2 * G.dealer.rob or 
                        - 2 * G.dealer.rob
    G.dealer.score = G.dealer.score +score
    table.insert(G.dealer.scores, score)
  end 
  for _,v in ipairs(players) do
    table.insert(result, { uin = v.uin, score = v.scores[#v.scores], bomb = v.bomb})
    v.total_bomb = v.total_bomb + v.bomb
  end
  
  G.round_result[G.round_id] = {}
  G.round_result[G.round_id].result = result
  G.round_result[G.round_id].ts = G.round_start_time[G.round_id]

  return result
end

-- 一局结束，可能再在多种情况下结束，需要分类讨论
function gfsm:onround_stoped(event, from, to)
  G.ROOM_STATE ="ACCOUNTS"
  local result = dealPlayerResult()

  -- 清除玩家的准备状态，下次开始游戏需要重新准备
  for _, p in ipairs(players) do
    p.ready = false
  end
  
  notify_players("pushRoundStates", {teg = {state = "TEG_ROUND_ACCOUNTS"}})
  --推送结果
  notify_players("pushRoundStoped", {teg = {playerresult = result }})
  
  if G.round_id == max_round then
    gfsm:game_over()
  end

end

function gfsm:onround_running()
  if not G.isVoteResume then
    notify_players("robStop", {winMode = G.winMode, rob = G.rob, banker = G.dealer.uin} )   -- 广播胜负模式与叫倍赢家

    if G.winMode =="OTHER" and G.rob == 1 then

      for _,v in ipairs(G.thecards) do table.insert(G.dealer.cards, v)  end
      table.sort( G.dealer.cards,  function (a, b)
          if a > b then
            return true
          end
        end)
      G.dealer.send_msg("pushCards", {uin = G.dealer.uin, cards = G.dealer.cards})
    elseif G.winMode == "SPRING" or G.rob == 4 then
      notify_players("pushShowCards", {
                        uin = G.dealer.uin, 
                        cards = G.dealer.cards}, 
                        G.dealer)
    end    
    G.current_play = G.dealer and G.dealer.profile.seatID or 1
    notify_players("pushRoundStates", {teg = {state = "TEG_ROUND_PLAY" }})
    G.ROOM_STATE = "PLAY"
    G.prev_cue = {}
    G.prev_cue_uin = nil
    notify_players("pushPlayerOperate", {teg = {uin = G.dealer.uin, type = "TEG_PLAY"}})
  end
end

local function gen_room_record(roomResult)
  local ret = mongox.safe_insert("room_record", {room_id = ROOM_ID, game_type = "TEG_GAME",  ts = G.room_start_time,
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
  for _,v in ipairs(players) do
     if v.score > index  then
        winnerId = v.uin
        index = v.score
     end
     local winCount = 0
     local loseCount = 0
     for _, w in ipairs(v.scores) do
        if w > 0 then
          winCount = winCount + 1
        else
          loseCount = loseCount + 1
        end
     end
     table.insert(roomResult, {uin = v.uin,  score = v.score , name = v.profile.name, winCount = winCount, 
      loseCount = loseCount, bomb = v.total_bomb})
  end
  notify_players("pushRoomStop", {teg = {playerAccounts = roomResult, winnerid = winnerId, gameTime = (os.time() - G.room_start_time)}})
  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  gen_room_record(roomResult)
end

--房间结束
function gfsm:ongame_stoped()
  game_stoped()
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
  if G.round_id ~= 0 then
     notify_players( "pushRoundPlayerState", {teg = {uin = player.uin, state = "TEG_READY"}} )
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
  print("next_index", G.current_play)
  notify_players("pushPlayerOperate", {teg = {
        type   = "TEG_PLAY",
        uin    = players[G.current_play].profile.id,
        first  = (G.prev_cards.seatID == G.current_play)
      }}) 
  if G.prev_cards.seatID ~= G.current_play then
    local status, cue = lib.searchCard(G.prev_cards.card_type, G.prev_cards.count, 
          G.prev_cards.groups, players[G.current_play].cards) 

    players[G.current_play].send_msg("pushCue", { teg = { cueStatus = status, cue = cue }})
    G.prev_cue = cue
    G.prev_cue_uin = players[G.current_play].uin 
  else
    G.prev_cards = {} 
    G.prev_cue = {}
    G.prev_cue_uin = nil
    G.first_player = players[G.current_play]
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

    --一回合先手时，重置缓存信息
    if pcards.count == nil then
      G.cache_cards = {}
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
  if ret ~= "ok" then
    return ret
  end

  if card_type == card_constant.CARD_TYPES.Boomb then
    player.bomb = player.bomb + 1
  end

  response_ok(player, "playCards")
  local remain = #player.cards
  notify_players("pushRoundPlayerState", {teg = {
      uin = player.uin,
      state = #cards > 0 and "TEG_PLAY" or "TEG_PLAY_SKIP"
      }
    })

  notify_players("pushPlayCards", {teg = {
    uin         = player.profile.id,
    cards       = cards,
    cardType    = card_type,
    remainCards = remain,
  }})

  if remain == 1 then
    if not player.single  then
      notify_players("pushRoundPlayerState", { teg = { uin = player.uin, state = "TEG_SINGLE" } } )
      player.single = true
    end
  end

  if remain > 0 then
   nextPlay()
  else
    G.WINNER = player
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
    print("PlayCards", G.current_play, player.profile.seatID)
    if G.current_play ~= player.profile.seatID then
      return "not_your_operate_order"
    else
      return play_card(player, cards)
    end
  end
end

local function agent_rob(player, msg)
  if not msg.skip then 
    local index = true
    for _,v in ipairs(G.canOper) do
      if v == msg.power then
        index = false
      end
    end
    if index then
      return "not_op_type"
    end
    response_ok(player, "rob")
    notify_players("pushRoundPlayerState", { teg = { 
            uin = player.uin, 
            state = "TEG_ROB", 
            num = msg.power}
          })

    player.rob = msg.power
    G.rob = msg.power
    G.dealer = player

    if msg.power ~= 5 then
      local index = 1
      for k,v in ipairs(G.canOper) do
        if v == msg.power then
          index = k
        end 
      end
      for i = index, 1, -1 do
        table.remove(G.canOper, i)
      end
    else
      G.winMode = "SPRING"   --"打春天"
      G.first_player = player
      G.dealer = player
      return gfsm:shuffle_card()
    end 

  else
    response_ok(player, "rob")
    player.rob_skip = true
    notify_players("pushRoundPlayerState", { teg = { 
      uin = player.uin, 
      state = "TEG_ROB_SKIP", 
      }})
  end

  if G.first_player and next_index(G.current_play) == G.first_player.profile.seatID then
    G.first_player = G.dealer
    G.winMode = "OTHER"
    return gfsm:shuffle_card()
  end
  G.current_play = next_index(G.current_play)
  notify_players("pushPlayerOperate", { teg = {
        uin = players[G.current_play].uin ,
        type = "TEG_ROB", 
        canOper = G.canOper }}) 
end


function command.Rob( source, msg )
  local player = find_player(source)
  if gfsm:is("round_started") then
    if player.profile.seatID ~= G.current_play then
      return "not_your_op_order"
    end
    agent_rob(player, msg)
  else
    return gfsm.current
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

function game.start(pls, roomID, roomType, MAX_USER, showType)
  G.room_start_time = os.time()
  ROOM_TYPE  = roomType
  ROOM_ID = roomID
  G.MAX_USER = MAX_USER
  SHOW_NUM_TYPE = (showType == "SHOW") and true or false

  ROOM_ID = roomID
  --局数
  if ROOM_TYPE == "FIVE_ROUNDS" then 
    max_round = 5 
  elseif ROOM_TYPE == "TEN_ROUNDS" then
    max_round = 10
  else
    max_round = 20
  end

  G.round_id = 0
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
    G.isVoteResume = true
    gfsm:resume()
  else
    return gfsm.current
  end
end

--针对重连用户的数据推送
function game.push_cache(player)
  if not player then return end

  INFO("offline deal : ", player.uin,  gfsm.current)

  local state, current_play_uin, ready, first, robData
  if gfsm:is("round_running") or gfsm:is("round_suspending") then
    state = "PLAY_CARDS"
    current_play_uin = players[G.current_play].uin
    first = not G.prev_cards.seatID and player.profile.seatID == G.current_play or G.prev_cards.seatID == G.current_play 
  elseif gfsm:is("game_started") or gfsm:is("round_stoped") then
    if not player.game_ready then
      state = "READY"
      ready = player.game_ready
    end
  elseif gfsm:is("round_started") then
    if G.ROOM_STATE == "ROB" then
      state = "ROB"
      current_play_uin = players[G.current_play].uin
      robData ={}
      for _,player in ipairs(players) do
        table.insert(robData, { uin = player.uin, rob = player.rob, skip = player.rob_skip })
      end
    end
  end

  if player and state then
    local cache_datas
    
    if state ~= "READY" then
      print("cache --- cards --- ", player.profile.seatID)
      utils.var_dump(G.cache_cards)
      cache_datas = {}
      for _, v in pairs(players) do
        local remain
        if SHOW_NUM_TYPE then
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

    player.send_msg("pushCache", { teg = { 
      state = state,
      currentPlay  = current_play_uin,
      cacheInfo = cache_datas,
      readyDatas = ready,
      first = first,
      cards = player.cards,
      roundId = G.round_id,
      robData = robData,
      banker = G.first_player.uin,
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
