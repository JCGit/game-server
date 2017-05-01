local skynet = require "skynet"

local utils = require "utils"

local command = {}
local rooms = {}
local gameTypes = {}

local NORET = {}

local function room_id()
  local rd = function() return utils.randomstring("0123456789", 6) end
  local id = rd()
  while rooms[id] do
    id = rd()
  end
  return id   --663982--
end

function command.OPEN_ROOM(uin, gameType)
  local id = room_id()
  if uin==10000001 or uin==1000002 then
   id='663982'
  end
  local room
  if gameType == "DN_GAME" then
      room = skynet.newservice("dnroom", id, uin)
  elseif gameType == "PDK_GAME" then
      room = skynet.newservice("pdkroom", id, uin)
  elseif gameType == "TEG_GAME" then
      room = skynet.newservice("tegroom", id, uin)
  elseif gameType == "QGW_GAME" then
      room = skynet.newservice("qgwroom", id, uin)
  end

  rooms[id] = room
  gameTypes[id] = gameType
  print("openRoom", gameType, gameTypes[id])
  return {id, room}
end

function command.LOOKUP_ROOM(roomid)
  if not roomid then
    return nil
  else
    return rooms[roomid]
  end
end

function command.GAME_TYPE( roomid  )
  if not roomid then
    return nil
  else
    return gameTypes[roomid]
  end
end

function command.DESTORY_ROOM(roomid)
  local room = rooms[roomid]
  if room then
    rooms[roomid] = nil
    gameTypes[roomid] = nil
    skynet.send(room, "lua", "EXIT")
  end
  return NORET
end

skynet.start(function()
  skynet.dispatch("lua", function(_, _, cmd, ...)
    local f = command[cmd]
    if f then
      local ok, ret = xpcall(f, debug.traceback, ...)
      if not ok then
        skynet.error(string.format("Handle message(%s) failed: %s", cmd, ret))
        return skynet.ret(skynet.pack {"Call failed"})
      elseif ret ~= NORET then
        return skynet.ret(skynet.pack(ret))
      end
    else
      skynet.ret(skynet.pack {"Unknown command"})
    end
  end)
end)
