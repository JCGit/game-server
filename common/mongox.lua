--- mongox redis服务高级接口
local mongox = {}

local skynet = require 'skynet'
local bson = require "bson"

local tonumber = tonumber

local MONGODB

function mongox.init(mongodb)
  MONGODB = mongodb
end

skynet.init(function ()
  print("mongox inf")
  MONGODB = skynet.queryservice('mongodb')
end)

function mongox.findOne(cname, selector, field_selector)
  return skynet.call(MONGODB, "lua", "findOne", cname, selector, field_selector)
end

function mongox.find(cname, opt)
  return skynet.call(MONGODB, "lua", "find", cname, opt)
end

function mongox.insert(cname, ...)
  return skynet.call(MONGODB, "lua", "insert", cname, ...)
end

function mongox.safe_insert(cname, doc)
  doc._id = bson.objectid()
  local ret = skynet.call(MONGODB, "lua", "safe_insert", cname, doc)
  ret._id = doc._id
  return ret
end

return mongox