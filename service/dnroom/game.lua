local skynet  = require "skynet"
local machine = require "statemachine"
local card_constant = require "dnroom.constant"
local lib = require "dnroom.lib"
require "logger_api"()
local inspect = require "inspect"
local mongox = require "mongox"

local CARD_MOUNT = card_constant.CARD_MOUNT
local ROOM_ID, DEALER_TYPE, ROOM_TYPE
local DEALER_MIN, PUBLIC_MAX_CHIP = 0, 0

local players
local G = {}   --模块通用变量
G.ROOM_START_TIME = nil
G.owner = nil
G.isPublic = nil   --是否有公海
G.isVoteResume = nil
G.max_user = nil
G.max_round = nil
G.round_id = nil
G.initScore = 1000
G.defaultpower = 1
G.shufflingPlayer = nil

local public_player = {}  --公海
local public_uin_flag = 1000000   --公海数据uin标识
local resultset = {}   --每局结束数据
local accounts = {}
local ROOM_STATE_TYPE = {
   "READY",
   "BET",
   "PUBLICBET",
   "ACCOUNTS",
   "SHUFFLING",
}
local ROOM_STATE = ROOM_STATE_TYPE[1]
local NIUTYPE = {  
  "NIU_SMALL",
  "NIU_NINE",
  "NIU_TEN",
  "NIU_FULL",
  "NIU_NIU",
}

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

local game = {}

-- 回复给agent状态是ok，当agent收到ok时不会把状态码发回给客户端
-- 而是由当前服务发回ok状态给客户端，这是为了保证与后面的消息时序一致
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

function gfsm:onstatechange(event, from, to)
  WARN("game state change: ", event, from, to)
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

function gfsm:ongame_started(event, from, to, pls)
  print("ongame_started",event, from, to, pls)
  players = pls
  G.max_user = #players
  PUBLIC_MAX_CHIP = tonumber(PUBLIC_MAX_CHIP) 
  G.isPublic = (DEALER_TYPE == "NO_DEALER") and false or (PUBLIC_MAX_CHIP and PUBLIC_MAX_CHIP > 0)  --有无公海

  --存放每轮结算
  for i = 1, G.max_round do       
   table.insert(resultset, {}) 
  end

  for _, player in ipairs(players) do
    player.score = G.initScore
    player.result = {}
    if player.profile.owner then
       G.owner = player   
    end
  end
  
  if G.isPublic then
    public_player.result = {}
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
local function resultfunc(player)
    local p_type, p_sum, p_set = lib.get_niu_type(player.cards)
    table.insert(player.result, { type= p_type, sum = p_sum , set = p_set })
end

local current_play      -- 当前出牌用户顺序


-- 一局开始洗牌发牌
function gfsm:onround_started()
  -- 初始化状态
  current_play = nil
  G.isVoteResume = nil
  G.shufflingPlayer = nil
  -- 增加局数
  G.round_id = G.round_id + 1
  for _, player in ipairs(players) do
    player.cards = {}      -- 初始化牌列表  
    player.beted = false      --是否已下注
    player.power = G.defaultpower               --下注倍数
    player.pulicebeted = false   --是否能给公海下注
    player.publicpower = 0         --公海下注倍数
    player.skip = nil
  end

  INFO("ROOM_ID: ", ROOM_ID, " round: ", G.round_id)
  
  notify_players("pushRoundStart", { roundId = G.round_id })  

  local cards = lib.shuffle_card(skynet.now(), CARD_MOUNT)

  --发牌逻辑
  local every_card_mount = 3  -- 潮汕斗牛每个玩家为3张牌
  for i, player in ipairs(players) do
    table.move( cards, ( i - 1 ) * every_card_mount + 1, i * every_card_mount, 1, player.cards)
    table.sort(player.cards)
    resultfunc(player)
  end
  local player_num = G.max_user + 1
  if G.isPublic then    --有公海发牌
      public_player.cards = {}
      public_player.power = 0     --公海被下注倍数
      table.move( cards,(player_num-1)*every_card_mount+1, player_num*every_card_mount,
            1, public_player.cards)  
      local type, sum, set = lib.get_niu_type(public_player.cards) 
      table.insert(public_player.result,{type = type, sum = sum, set =set }) 

  end
  
  return self:shuffle_card()
end

--下一个玩家
local function next_index(pre)
  local index = pre + 1
  index = (index > G.max_user) and 0 or index
  return index
end


local function showCardDeal()   --处理没亮牌的亮牌
   for _,v in ipairs(players) do                
        notify_players("pushshowcard", { uin = v.uin, 
                        cards = v.cards,
                        niutype = NIUTYPE[tonumber(v.result[G.round_id].type)],
                        sum = v.result[G.round_id].sum
                        }, v)   --没亮牌的亮牌
  end
  if G.isPublic then
     notify_players("pushshowcard", { 
                   uin = public_uin_flag,
                   cards = public_player.cards ,
                   niutype = NIUTYPE[tonumber(public_player.result[G.round_id].type)],
                   sum = public_player.result[G.round_id].sum
                   })  -- 有公海亮牌
  end
end


--计算公海
local function dealPublic(theplayer)
    local def_score = 0
    if G.isPublic then
       local result = lib.compare(public_player.result[G.round_id], theplayer.result[G.round_id], DEALER_TYPE, DEALER_MIN)
       local score = (result == "WIN") and public_player.result[G.round_id].type * public_player.power or def_score 
                        - theplayer.result[G.round_id].type * public_player.power
       for _,v in ipairs(resultset[G.round_id]) do
          if v.uin == theplayer.uin then
              v.publicscore = def_score - score
          else
              for _,player in ipairs(players) do
                if v.uin == player.uin then 
                   v.publicscore = (result == "WIN") and public_player.result[G.round_id].type * player.publicpower or
                      def_score - theplayer.result[G.round_id].type * player.publicpower
                end
              end
          end
        end
    end
end

-- 一局结束，可能再在多种情况下结束，需要分类讨论
function gfsm:onround_stoped(event, from, to)
  showCardDeal()
  ROOM_STATE = ROOM_STATE_TYPE[4]
  notify_players("pushRoundStates", {bull = 
          {state = "ROOM_ACCOUNTS"}
        })
  -- 清除玩家的准备状态，下次开始游戏需要重新准备
  for _, p in ipairs(players) do
    p.ready = false
  end
  --有庄
  local dealer = G.owner
  if DEALER_TYPE == "HAVE_DEALER" then
      local d_score = 0
      --闲家胜负 
      for _,v in ipairs(players) do
         if not v.profile.owner then
            local v_result = lib.compare(v.result[G.round_id], dealer.result[G.round_id], DEALER_TYPE, DEALER_MIN)
            local score = 0
            if v_result == "WIN" then 
               score = v.result[G.round_id].type * v.power
            elseif v_result == "TIE" then
               score = 0
            else
               score =  - dealer.result[G.round_id].type * v.power
            end
            table.insert(resultset[G.round_id], {result = v_result, uin = v.uin, modifyscore = score, cards = v.cards,
                  publicscore = 0, niutype = NIUTYPE[v.result[G.round_id].type], sum = v.result[G.round_id].sum } )
            d_score = d_score - score
         end
      end
      local result
      --庄家计算
      --默认房主为庄家
      if d_score > 0 then
        result = "WIN"
      elseif d_score == 0 then
        result = "TIE"
      else
        result = "LOSE"
      end 
      table.insert(resultset[G.round_id], { result = result, uin = dealer.uin, modifyscore = d_score, cards = dealer.cards, 
           publicscore = 0, niutype = NIUTYPE[dealer.result[G.round_id].type], sum = dealer.result[G.round_id].sum } )
      dealer.score = dealer.score + d_score
      dealPublic(dealer)
  else
    --无庄
    local winner = G.owner
    for _,v in ipairs(players) do
       if v.uin ~= G.owner then
          local v_result = lib.compare(v.result[G.round_id], winner.result[G.round_id], DEALER_TYPE, DEALER_MIN)
          if v_result == "WIN" then
             winner = v
          end
        end
    end
    local score, w_score = 0, 0
    local def_score = 0
    for _,v in ipairs(players) do
       if v.uin ~= winner.uin then 
          score = v.result[G.round_id].type * v.power
          table.insert(resultset[G.round_id], { result = "LOSE", uin = v.uin, modifyscore = def_score - score  , cards = v.cards, 
               publicscore = def_score, niutype = NIUTYPE[v.result[G.round_id].type], sum = v.result[G.round_id].sum } )

          w_score = w_score + score
       end
    end
    table.insert( resultset[G.round_id], { result = "WIN", uin = winner.uin, modifyscore = def_score + w_score, cards = winner.cards, 
         publicscore = def_score, niutype = NIUTYPE[winner.result[G.round_id].type], sum = winner.result[G.round_id].sum} )
  end
  --推送结果
  notify_players("pushRoundStoped", {bull = {playerresult = resultset[G.round_id]}})
  for _,player in ipairs(players) do
     for _,v in ipairs(resultset[G.round_id]) do
        if player.uin == v.uin then
          player.score = player.score + v.modifyscore + v.publicscore    --计算本轮积分变化
        end
     end
  end
  if G.round_id == G.max_round then
    gfsm:game_over()
  end
end

--操作推给下个玩家
local function currentnext(type, current_play)
  -- body
  if current_play <= G.max_user and current_play ~= 0 then
      notify_players("pushPlayerOperate", {bull = {
             type  = type,
             uin   = players[current_play].profile.id,
             num   = PUBLIC_MAX_CHIP - public_player.power,
          }})
      return true
  else 
      return false
  end
end 


function gfsm:onround_running()
  if not G.isVoteResume then
    if gfsm:is("round_running") then
      notify_players("pushRoundStates", {bull = {
         state = "ROOM_BET"
        }})
      ROOM_STATE = ROOM_STATE_TYPE[2]
      if DEALER_TYPE == "HAVE_DEALER" then 
        notify_players("pushPlayerOperate", { bull = {
             type = "BET",
             uin  = nil
             }}, G.owner)       
        current_play = 2
      else
        notify_players("pushPlayerOperate", { bull = {
             type = "BET",
             uin  = nil
             }})
        current_play = 1
      end

    else
      return gfsm.current
    end
  end
end

--计算房间结算数据
local function sumResult()
  local scoreset, niuset = {}, {}
  for i=1,G.round_id do
    for _,v in ipairs(resultset[i]) do
       if v then
          local score = v.modifyscore + v.publicscore
          if not scoreset[v.uin] then
             scoreset[v.uin] = score
          else
             scoreset[v.uin] = scoreset[v.uin] + score
          end
          if not niuset[v.uin] then
             niuset[v.uin] = {}
             for _,n in ipairs(NIUTYPE) do 
                niuset[v.uin][n] = 0
             end
             niuset[v.uin][v.niutype] = niuset[v.uin][v.niutype] + 1
          else
             niuset[v.uin][v.niutype] = niuset[v.uin][v.niutype] + 1
          end
        end   
    end
  end 
  return scoreset, niuset
end

-- 生成战绩
local function gen_room_record()
  if #players == 0 or #resultset == 0 then
    return
  end

  local scoreset = sumResult()

  local room_result = {}
  for _, v in pairs (players) do 
     -- sorce 这个玩家这轮积分的变化
    table.insert(room_result, {name = v.profile.name, uin=v.uin, score = scoreset[v.uin]})
  end

  local ret = mongox.safe_insert("room_record", {room_id = ROOM_ID, game_type = "DN_GAME", ts = G.ROOM_START_TIME,
    room_result = room_result, round_result = resultset})

  -- ts 等于房间开始时间
  for _, v in ipairs(players) do
    mongox.safe_insert("player_room_record", {uin = v.uin, room_db_id = ret._id, ts = G.ROOM_START_TIME})
  end
end

local function game_stoped()
  -- body
  local scoreset,niuset = sumResult()
  for _,v in pairs(niuset) do
     v["NIU_SMALL"] = nil         --牛小不往前端推送
  end
  local winnerid, temp = 0, 0
  for j,s in pairs(scoreset) do
     if s > temp then
        winnerid = j
        temp = s
     end

     for i,n in pairs(niuset) do
        if  j == i then
           table.insert(accounts, {uin = j, modifyscore = s, niucount = {n["NIU_NIU"], n["NIU_FULL"], n["NIU_TEN"], n["NIU_NINE"] }})
        end
     end
  end

  if not resultset[G.round_id].result and G.round_id == 1 then  --一局都没打完的情况
     for _,v in ipairs(players) do
         table.insert(accounts, {uin = v.uin, modifyscore = 0, niucount = {0, 0, 0, 0} })
     end
  end       
  notify_players("pushRoomStop", {bull = {playeraccounts = accounts, winnerid = winnerid, gameTime = (os.time() - G.ROOM_START_TIME)}})

  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  gen_room_record()
end

--房间结束
function gfsm:ongame_stoped()
  game_stoped()
  skynet.send(".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID) 
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
     notify_players("pushRoundPlayerState", {bull = {uin = player.uin, state = "READY"}}, player)
  end

 local readyindex = true
  for _, v in ipairs(players) do
    if not v.ready then
      readyindex = false
    end
  end

  if readyindex and G.max_user > 1 then
     gfsm:go_next_round()
  end
end

local function offLineCache()
   local cache = {}
   for _,player in ipairs(players) do
    table.insert(cache, { uin = player.uin,
                ready = player.ready,
                beted = player.beted,
                power = player.power,
                pulicebeted = player.pulicebeted,
                publicpower = player.publicpower,
                skip = player.skip,
                })
   end
   return cache
end

--断线重连
local function reConnectDeal(player)
    print("ReConnectDeal", inspect(player))
    local playercache = offLineCache()

    if gfsm:is("round_running") then
       player.send_msg( "pushPlayCards", {bull = {cards = player.cards, 
                    niutype = NIUTYPE[player.result[G.round_id].type], 
                    sum = player.result[G.round_id].sum 
                    }})

       player.send_msg("pushCache", {bull= {state = ROOM_STATE,
                    currentPlay = players[current_play].uin,
                    playercache = playercache,
                    canPublicPower = G.isPublic and (PUBLIC_MAX_CHIP - public_player.power) or nil,
                    roundid = G.round_id,
                    shufflingPlayer=G.shufflingPlayer and G.shufflingPlayer.uin or nil, 
                   }})
    elseif gfsm:is("round_stoped") then
      if not player.ready then    -- 未准备阶段，推结算
         if G.isPublic then
            player.send_msg("pushshowcard", { 
                   uin = public_uin_flag,
                   cards = public_player.cards ,
                   niutype = NIUTYPE[tonumber(public_player.result[G.round_id].type)],
                   sum = public_player.result[G.round_id].sum
                   })
         end
         player.send_msg( "pushCache", {bull = {state = ROOM_STATE, result = resultset[G.round_id], roundid = G.round_id }} )   --推送单局结算
      else
         player.send_msg( "pushCache", { bull = {state = ROOM_STATE, 
                            result = resultset[G.round_id],
                            playercache = playercache,
                            roundid = G.round_id,
                             }} ) 
      end
    elseif gfsm:is("round_suspending") then
         if #player.cards ~= 0 and #player.result[G.round_id] ~= 0 then 
            player.send_msg( "pushPlayCards", {bull = { cards = player.cards, 
                    niutype = NIUTYPE[player.result[G.round_id].type],
                    sum = player.result[G.round_id].sum
                    }})
         end 
         player.send_msg( "pushCache", {bull = {state = ROOM_STATE,
                  currentPlay = players[current_play].uin, 
                  playercache = playercache, 
                  canPublicPower = G.isPublic and (PUBLIC_MAX_CHIP - public_player.power) or nil,
                  roundid = G.round_id,
                  shufflingPlayer = G.shufflingPlayer and G.shufflingPlayer.uin or nil
                   }})
    elseif gfsm:is("game_stoped") then
         return "game_stoped"
    else
      return gfsm.current
    end
end

--下注结束
local function betover()
  for _,player in ipairs(players) do    --推牌
      player.send_msg("pushPlayCards", {bull ={
      cards    = player.cards,
      niutype  = NIUTYPE[player.result[G.round_id].type],
      sum      = player.result[G.round_id].sum
    }})
  end
  if G.isPublic then
     current_play = 2  
     currentnext("PUBLICBET", current_play)
     ROOM_STATE = ROOM_STATE_TYPE[3]
     notify_players("pushRoundStates", { bull = {
        state = "ROOM_PUBLIC_BET"
      }})
  else
     gfsm:round_over()
  end
end

--处理下注
local function agent_bet(player, power)
     response_ok(player, "bet")
    notify_players("pushRoundPlayerState", {bull = {
          uin          = player.profile.id,
          state  = "BETED",
          num       = power,
          }})
    player.power = power
    player.beted = true
    local index = nil
    for _,v in ipairs(players) do
        if not v.beted then
           index = true
          if DEALER_TYPE == "HAVE_DEALER" and v.uin == G.owner.uin then 
           index = false
          end
        end
    end
    if not index then
       betover()
    end 
end

--轮公海结束
local function publicBetOver()
  notify_players("pushRoundStates", {bull = {state = "ROOM_PUBLIC_BET_OVER"}})
  local temp = {}
  local temp_index = 2   --房主为庄
  for _, v in ipairs (players) do
    if v.uin ~= G.owner.uin then
      if v.publicpower > players[temp_index].publicpower then 
         temp_index = v.profile.seatID
      end
    end
  end
  table.insert(temp, players[temp_index])
  for _, v in ipairs(players) do
    if v.uin ~= G.owner.uin then
       if v.publicpower == players[temp_index].publicpower then 
          table.insert(temp, v)
       end
    end
  end
  local index = math.random(1, #temp)
  current_play = temp[index].profile.seatID
  ROOM_STATE = ROOM_STATE_TYPE[5]
  G.shufflingPlayer = temp[index]
  temp[index].send_msg("pushPlayerOperate", {bull = {type = "SHUFFLING", uin = temp[index].uin}})
  notify_players("pushRoundPlayerState", {bull = {uin = temp[index].uin, state = "SHUFFLING"}})
end


--处理公海下注
local function public_bet(player, type, power)
  -- body
   if G.isPublic then --公海下注
      response_ok(player, "bet")
      if type == "PUBLICBET" then       --公海下注      
          public_player.power = public_player.power + power
          player.pulicebeted = true
          player.publicpower = power
          if public_player.power < PUBLIC_MAX_CHIP then
             notify_players("pushRoundPlayerState", {bull = {
                   uin          = player.profile.id,
                   state  = "PUBLICBET",
                   num       = power,
                   }})
          else
             notify_players("pushRoundPlayerState", {bull = {
                   uin          = player.profile.id,
                   state  = "PUBLICBET",
                   num       = power,
                   status    = "public_power_upper_limit"
                   }}) 
             skynet.sleep(100)
             publicBetOver()
            return
          end
      else
        player.pulicebeted = true
        player.publicpower = 0
        player.skip =true
        notify_players("pushRoundPlayerState", {bull = {       --广播跳过公海下注
               uin          = player.profile.id,
               state  = "SKIP",
              }})
      end
      current_play = next_index(current_play)
      if not currentnext("PUBLICBET", current_play) then
        publicBetOver()
      end
    else
      return "not_public"
    end   
end

--下注
function command.BET(source,msg)
  local player = find_player(source)
  if gfsm:is("round_running") then
     if msg.bettype == "BET" or not msg.bettype then
        if ROOM_STATE == "BET" then
           if player.beted then
              return "have_beted"
           elseif DEALER_TYPE == "HAVE_DEALER" and player.uin == G.owner.uin then   --有庄，庄家不能下注
              return  "not_op_type"
           else
             agent_bet(player, msg.power)
           end
        else
           return "not_op_type"
        end
     elseif msg.bettype == "PUBLICBET" or msg.bettype == "SKIP_PUBLIC" then 
        if ROOM_STATE == "PUBLICBET" then
           if current_play ~= player.profile.seatID then
             return "not_your_op_order"
           end
           public_bet(player, msg.bettype, msg.power)
        else
           return "not_op_type"
        end
     end
  else
    return gfsm.current
  end
end


function game.command(cmd, source, ...)
  local f = command[cmd]
  if not f then
    return false, "Unknown command"
  end
  return xpcall(f, debug.traceback, source, ...)
end

function game.start(pls, roomID, roomType, dealerType, dealer_min, public_max_chip)
  G.ROOM_START_TIME = os.time()
  ROOM_TYPE  = roomType
  DEALER_TYPE = dealerType
  DEALER_MIN = tonumber(dealer_min)
  PUBLIC_MAX_CHIP = public_max_chip and public_max_chip or 0
  ROOM_ID = roomID
  --局数
  if ROOM_TYPE == "FIVE_ROUNDS" then 
    G.max_round = 5 
  elseif ROOM_TYPE == "TEN_ROUNDS" then
    G.max_round = 10
  else
    G.max_round = 20
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
  -- body
  if gfsm:is("round_suspending") then
     G.isVoteResume = true
     gfsm:resume()
  else
    return gfsm.current
  end
end

function game.roundStop()
  if gfsm:is("round_running") then
     gfsm:round_over()
  else
     return gfsm.current
  end
end

--针对重连用户的数据推送
function game.push_cache(player)
  INFO("offline deal : ", player.uin,  gfsm.current)
  reConnectDeal(player)
end

function game.exit()
  --战绩保存,考虑引入消息队列，可能房间已经销毁了
  game_stoped()
  skynet.send(".room_mgr", "lua", "DESTORY_ROOM", ROOM_ID) 
end

function game.info()
  print("fsm->current -------", gfsm.current)
end

return game
