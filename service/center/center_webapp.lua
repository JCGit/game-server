local route = ...

local skynet = require "skynet"
local json = require "cjson"
local inspect = require "inspect"

local center = skynet.localname(".centerservice")

route["/gm"] = function(method, query, body)
    print("gm ----- request")
    local res = skynet.call(center, "lua", "GM", method, query, body)
    local rets = {
        status = -1,
        content = "",
        msg = "Code error"
    }
    if res then
        if type(res) == "table" then
            for k,v in pairs(res) do
                rets[k] = v
            end
        end
    end
    
    skynet.error("GM result:".. inspect(res))
    return 200, json.encode(rets)
end



