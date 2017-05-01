local settings = require 'settings'
local ipStr = settings.gate_host .. ":" .. settings.gate_port

local M = {
    version = 2016091314,
    serverAddress = {
        -- addressId = {addressId, outerIp, innerIp}
        [1] = { id = 1, outerIp = ipStr, name = "hall"}
    },

    server2address = {
        --worldId = {curWorldId, addressId}
        [1] =  {1, 1},
        [2] =  {2, 1}
    },
}

return M
