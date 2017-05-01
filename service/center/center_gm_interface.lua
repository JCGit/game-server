local skynet = require 'skynet'
local stringx = require 'sl.stringx'
local constant = require 'constant'
local utils = require 'utils'
local json = require "cjson"
local md5 = require "md5"

local M = {}

local function addticket_check(data)
    local keys = {
        "uin",          -- uin
        "count",        -- 数量
    }

    for _,v in pairs(keys) do
        if not data[v] then
            return {false, '缺少参数'}
        end
    end

    return {true, constant.gm_appoint.to_agent, data.uin}
end

local function getinfo_check(data)
    local keys = {
        "uin",          -- uin
    }

    for _,v in pairs(keys) do
        if not data[v] then
            return {false, '缺少参数'}
        end
    end

    return {true, constant.gm_appoint.to_agent, data.uin}
end

--------------

local function decode_func(c)
    return string.char(tonumber(c, 16))
end

local function decode(str)
    local str = str:gsub('+', ' ')
    return str:gsub("%%(..)", decode_func)
end

local gmcmd = {
    addicket = addticket_check,
    getinfo   = getinfo_check, 
}

function M.verify_cmd(method, res)
    if not res.cmd or not gmcmd[res.cmd] then
        return {false}
    end
    return {true}
end

--校验参数
function M.verify_data(method, res)
    return gmcmd[res.cmd](res.decode_data)
end

--校验签名
function M.verify_sign(res)
    local key = "S8NC4ggqhkVhZgxWXIZPAGzjkibvIOE2"
    if not res or not res.sign or not res.data then
        return false
    end

    return md5.sumhexa(res.data .. key) == res.sign
end

-- 解析数据
function M.parse(query, body)
    local res = {}

    for k,v in pairs(query) do
        res[k] = v
    end

    if body then
        local t = stringx.split(body, '&')
        for i=1,#t do
            local k2v = stringx.split(t[i], '=')
            if #k2v == 2 then
                res[k2v[1]] = decode(k2v[2])
            end
        end
    end

    local function checkParams(tab)
        if not tab or type(tab) ~= "table" then
            return
        end

        for k,v in pairs(tab) do
            if type(v) == "function" then
                tab[k] = nil
            elseif type(v) == "table" then
                checkParams(v)
            end
        end
    end
   
    if res.data then
        res.decode_data = json.decode(res.data)
        checkParams(res.decode_data)
    end
    return res
end

return M
