local skynet = require "skynet"
local inspect = require "inspect"
local mongox = require "mongox"

local send_message, send_status = send_message, send_status
local M = {}

-- 所有的sql查询都应该做必要的缓存
register_msg_handler("getRecord", function(rpcid, msg)
  -- mongo 中 player_room_record 查找 room_db_id, 再到room_record中查找数据

  local time = skynet.time() - 24 * 60 * 60  --现在先查询一天的量，个数限制为10个
  local limit = 0
  if msg.gameType == "DN_GAME" then
    limit = 10
  else
    limit = 2
  end

  local find_opt = {
    selector = {uin = msg.uin,  ts = {['$gt'] = time}},
    sort = {ts = 1},
    limit = limit,
  }
  local set = mongox.find("player_room_record", find_opt)
 
  if not set or #set == 0 then
    send_message(rpcid, {records= {}})
    return    
  end

  local record_set = {}
  local item = {}
  local utils = require "utils"

  if msg.gameType and msg.gameType == "PDK_GAME" or msg.gameType == "TEG_GAME" then
    for _, v in ipairs(set) do
      item = mongox.findOne("room_record",  {_id = v.room_db_id})
      if item.game_type == msg.gameType then
        local name_map = {}
        for k, v in ipairs(item.room_result) do
          name_map[v.uin] = v.name
        end

        for k, v in ipairs(item.round_result) do
          local r = {}
          r.roomId = item.room_id
          r.roundId = k
          r.playerRecord = v.result
          r.data = v.ts
          r.name = name_map[v.uin]
          r.gameType = item.game_type
          table.insert(record_set, r)
        end
      end
    end
  elseif msg.gameType == "DN_GAME" then
    for _, v in ipairs(set) do
      item = mongox.findOne("room_record",  {_id = v.room_db_id})
      if item.game_type == msg.gameType then 
        local t = {}
        t.roomId = item.room_id
        t.date = item.ts
        t.playerRecord = item.room_result
        t.gameType = item.game_type
        table.insert(record_set, t)
      end
    end
  end
  return send_message(rpcid, {records= record_set})
end)

--查询房间每轮数据
local function getRoundRecord(rpcid, msg)
  local find_opt = {selector={room_db_id = msg.room_db_id, round_id = msg.round_id}}
  local set = mongox.find("room_round_record", find_opt)
  local recordRoundSet = {}
  for _,v in ipairs(set) do   --单局结算或房间所有轮数结算数据
     table.insert(recordRoundSet,v)
  end
  return recordRoundSet
end

return M
