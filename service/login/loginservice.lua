local skynet = require "skynet"
local login  = require "snax.loginserver"
local crypt  = require "crypt"
local redisx = require 'redisx'
local settings = require 'settings'
local constant = require 'constant'
local platfrom = require 'login.platfrom'
local utils = require 'utils'
local sharedata = require "sharedata"
local cluster = require "cluster"
require "logger_api"()

local gate
local hall_list = {}
local user_login = {}
local white_list

local inspect = require 'inspect'

skynet.info_func(function ()
    return inspect {
        server     = hall_list,
        user_login = user_login,
    }
end)

local function gen_unique_username()
    local r = crypt.base64encode(crypt.randomkey())
    return ('guest_%s@%s'):format(r, skynet.time())
end

local function auth_handler(token)
    -- userdata 是用户自定义数据
    local user,loginServerIndex, password, pf,userdata = token:match("([^@]+)@([^:]+):([^:]+):([^?]+)%??(.*)")
    user = crypt.base64decode(user)
    loginServerIndex = tonumber(crypt.base64decode(loginServerIndex))

    pf = crypt.base64decode(pf)
    pf = tonumber(pf) or pf
    password = crypt.base64decode(password)
    userdata = userdata and crypt.base64decode(userdata)

    skynet.error('KEY POINT', '认证客户端token: ', user, loginServerIndex, password, pf, userdata)

    local platform_name = constant.platfrom_type[pf]
    assert(platfrom.platfrom_permission_check[platform_name](pf, user, password,
      userdata), "platfrom auth failed")

    local uin = redisx.hgetstring("uin_mapping", user)
    if not uin then
        redisx.setnx("uin", constant.uin_min_value)
        uin = tostring(redisx.incrby("uin", 1))
        redisx.hsetstring('uin_mapping', user, uin)
        redisx.hsettable(constant.uin_info_key, uin, {
          uin         = uin,
          create_time = os.time(),
        })
    end

    -- local mapping_key = 'account:uin_mapping'
    -- local uin = redisx.hgetstring(mapping_key, uin)
    -- if not uin then
    --     local MUIN = 'account_max_uin'
    --     redisx.setnx(MUIN, 1000000)
    --     uin = redisx.incrby(MUIN, 1)
    --     redisx.hsetstring(mapping_key, uin, uin)
    --     redisx.hsettable(constant.uin_info_key, uin, {
    --       uin         = uin,
    --       create_time = os.time(),
    --     })
    -- end

    skynet.error('KEY POINT', '用户校验成功: ', user, uin)

    return loginServerIndex.."-"..pf,uin
end

--- 登录handler
-- 登录框架使用认证接口返回的 server 和uin来登录
-- @function login_handler
-- @string server 服务地址
-- @int uin uin
-- @string secret 加密通信用的aes keyl
-- @within handlers
-- @return[1] subid 成功登陆，正常返回subid
-- @return[2] error 登陆失败 error结束
-- @see auth_handler

local game_server_info

-- 是否有封号
local function allowLogin(uin)
    local time = redisx.hgetstring("player_locked", uin)
    if time and tonumber(time) > os.time() then
        return false
    end
    return true
end

local function inWhiteList(uin)
    for k,v in pairs(white_list or {}) do
        if tonumber(v) == tonumber(uin) then
            return true
        end
    end
    return false
end

local function login_handler(loginstr, uin, secret)
    local loginServerIndex,pf = loginstr:match("([^-]+)-(.+)")
    loginServerIndex = tonumber(loginServerIndex)
    assert(game_server_info.server2address[loginServerIndex],
      "login_handler failed! world noFound ID=" .. loginServerIndex)


    local curLoginServerIndex = game_server_info.server2address[loginServerIndex][1]
    local hallIndex = game_server_info.server2address[loginServerIndex][2]
    local loginAddress = game_server_info.serverAddress[hallIndex]
    assert(loginAddress, "hallAddress no found ID=" .. hallIndex)
    assert(hall_list[loginAddress.name], "hallName no found name=" .. loginAddress.name)
    if allowLogin(uin) then
        skynet.error("KEY POINT", "开始登录游戏服务器:", uin, loginAddress.outerIp, loginServerIndex, curLoginServerIndex)
        local subid = cluster.call(loginAddress.name.."node", hall_list[loginAddress.name], "login", uin, secret, pf)
        return loginAddress.outerIp..'@'..uin ..'@'..subid
    else
        assert(false, 'player@locked')
    end
end

local CMD = {}

function CMD.reload()
    skynet.error("==============================:cluster conf reload")
    cluster.reload()
end

function CMD.update_game_server_info()
    game_server_info = redisx.getvalue("gameserverlist")
    sharedata.update("game_server_info",game_server_info)
    skynet.error("update_game_server_info----------------->:"..inspect(game_server_info))
end

function CMD.update_white_list()
    white_list = redisx.getvalue("whitelist")
end

function CMD.init()
    --获取服务器列表信息
    game_server_info = redisx.getvalue("gameserverlist")
    assert(game_server_info)
    sharedata.new("game_server_info", game_server_info)

    white_list = redisx.getvalue("whitelist")

    --获取所有hall地址
    for _,v in pairs(game_server_info.serverAddress) do
        local nodeName = v.name .."node"
        local res,address = pcall(cluster.query, nodeName, v.name)
        if res then
            hall_list[v.name] = address
            skynet.error("init hall address ", v.name ,address)
        end
    end

    local ok, ret = xpcall(cluster.call, debug.traceback, "centernode", ".centerservice", "register_login",  skynet.self())
    if not ok then
        skynet.error(ret)
    end

    cluster.register("loginservice")
end

--- hall注册
-- @within CMD
function CMD.register_hall(server, address)
    hall_list[server] = address
    utils.var_dump(hall_list)
end

--- logout: 游戏服务器来向登录服务器通知用户退出(用户主动logout时)
-- @within CMD
function CMD.logout(uin, subid)
    local u = user_login[uin]
    user_login[uin] = nil
    if u then
    end
end

local function command_handler(command, ...)
    if dev_login_log then
        skynet.error('command: ', command, ...)
    end

    return CMD[command](...)
end

login {
    host            =  '0.0.0.0',
    port            = settings.login_conf.login_port,
    multilogin      = false, -- 禁用多点登录模式
    name            = "G",
    instance        = settings.login_conf.login_slave_cout, -- slave instance
    command_handler = command_handler,
    login_handler   = login_handler,
    auth_handler    = auth_handler,
}
