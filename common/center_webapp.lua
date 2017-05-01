local app = ...

local skynet = require 'skynet'
local table = table
local string = string
local settings = require "settings"
local inspect = require 'inspect'
local json = require "cjson"

local centerservice = skynet.localname(".centerservice")

app.clear_all()

app.match('/gmmanager', function (method, query, body)
    local res = skynet.call(centerservice, "lua", "gm", method, query, body)
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
    skynet.error("GM_RESULT:".. inspect(res))
    return 200, json.encode(rets)
end)

