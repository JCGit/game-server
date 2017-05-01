local skynet = require "skynet"
local constant = require "constant"
local redisx = require "redisx"
local utils = require "utils"

local hall

local CMD = {}
function CMD.getinfo(datas)
	local uin = tonumber(datas.uin)
 	local agent  = skynet.call(hall, "lua", "get_agent", uin)
 	local data 
 	if agent then
        data = skynet.call(agent, 'lua', 'profile_mod', 'basic_profile')
 	else
 		data = redisx.hgettable("user:profile", uin)
 	end

 	if not data then
 		return constant.genGmResp(constant.gm_resp_type.user_not_found)
 	end

 	return utils.makeGmManagerValue(constant.gm_response_type.success, data)
end

function CMD.addticket(datas)
    local uin = tonumber(datas.uin)
    local count = tonumber(datas.count)
    local agent  = skynet.call(hall, "lua", "get_agent", uin)
    local ticket = 0
    if agent then
        ticket = skynet.call(agent, 'lua', 'profile_mod', 'room_ticket', count)
    else
        local data = redisx.hgettable("user:profile", uin)
        data.room_ticket = data.room_ticket + count
        ticket = data.room_ticket
        redisx.hsettable("user:profile", uin,  data)
    end

    return utils.makeGmManagerValue(constant.gm_response_type.success, ticket) 
end

skynet.start(function()
	hall = skynet.localname(".hall")

    skynet.dispatch("lua", function (_, _, cmd, ...)
        skynet.error("gm cmd " .. cmd)
        local f = CMD[cmd]
        if f then
            local ok, res = pcall(f,...)
            if not ok then
                skynet.retpack({msg=res})
            else
                skynet.retpack(res)
            end
        else
            local rets = constant.genGmResp(constant.gm_resp_type.method_not_found)
            return skynet.retpack(rets)
        end
    end)
end)

