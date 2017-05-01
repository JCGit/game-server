local skynet = require "skynet"
local cluster = require "cluster"

local redisx = require "redisx"
local server_list_conf = require "server_list_conf"
local center_gm_interface = require "center_gm_interface"
local constant = require "constant"

local inspect = require "inspect"

local game_server_info
local CMD = {}
local hall_list = {}
local login_service

function CMD.register_hall(server, address)
    hall_list[server] = address
end

function CMD.register_login(address)
    login_service = address
end

local function noticeAll(room, req_content)
    local ok, res = xpcall(cluster.call, debug.traceback, "hallnode", ".gm", 
         req_content.cmd, req_content.decode_data)
    if not ok then
        return constant.genGmResp(constant.gm_resp_type.call_failed)
    else
    -- { status = 0, msg = res}
        return res
    end
end

local function noticeAgent(uin, req_content)
    local ok, res = xpcall(cluster.call, debug.traceback, "hallnode", ".gm", 
         req_content.cmd, req_content.decode_data)
    if not ok then
        return constant.genGmResp(constant.gm_resp_type.call_failed)
    else
        return res
    end
end

local function gmCmd(method, query, body)
    local req_content = center_gm_interface.parse(query, body)
    skynet.error("GM data:".. inspect(req_content))

    if not center_gm_interface.verify_sign(req_content) then
        return constant.genGmResp(constant.gm_resp_type.sign_failed)
    end

    local resp_data = center_gm_interface.verify_cmd(method, req_content)
    if not resp_data[1] then
        return constant.genGmResp(constant.gm_resp_type.method_not_found)
    end

    print("----------- cmnd ----------------")
    local resp_data = center_gm_interface.verify_data(method, req_content)
    if not resp_data[1] then
        return constant.genGmResp(constant.gm_resp_type.params_failed)
    end

    --个人
    if resp_data[2] == constant.gm_appoint.to_agent then
        return noticeAgent(resp_data[3], req_content) -- uin, content
    --全服
    elseif resp_data[2] == constant.gm_appoint.to_all then
        return noticeAll(resp_data[3], req_content)
    end
end

skynet.init(function()
    --逻辑服的地址依赖于redis中serverlist的值
    --获取所有服务器列表信息
    game_server_info = redisx.getvalue("gameserverlist")
    if not game_server_info or game_server_info.version < server_list_conf.version then
        game_server_info = server_list_conf
        redisx.setvalue("gameserverlist", game_server_info)
       skynet.error("gameserverlist init done version=" .. server_list_conf.version)
    end

    --获取所有hall服务地址
    for _,v in pairs(game_server_info.serverAddress) do
        local nodeName = v.name .."node"
        local res,address = pcall(cluster.query, nodeName, v.name)
        if res then
            hall_list[v.name] = address
            skynet.error("init hall address ", v.name ,address)
        end
    end

    --获取login进程loginservice地址
    local res,address = pcall(cluster.query, "loginnode", "loginservice")
    if res then
        login_service = address
        skynet.error("init login address ",login_service)
    end
end)

local traceback = debug.traceback
skynet.start(function()
        skynet.dispatch("lua", function (_, _, cmd, ...)
        if cmd == "GM" then
          local ok, res = xpcall(gmCmd, traceback, ...)
          if not ok then
            skynet.error(res)
            skynet.retpack({msg=res})
          else
            skynet.retpack(res)
          end
        else
          local f = CMD[cmd]
          if f then
            skynet.retpack(f(...))
          else
            skynet.retpack("Unknow command")
          end
        end
    end)
end)
