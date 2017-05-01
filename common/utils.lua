local random, rep = math.random, string.rep
local string_format = string.format
local table_insert  = table.insert
local table_concat  = table.concat
local utils = {}

-- 拷贝obj中的数据到新表中
local function simple_copy_obj(obj)
  if type(obj) ~= "table" then
    return obj
  end
  local ret = {}
  for k, v in pairs(obj) do
    ret[simple_copy_obj(k)] = simple_copy_obj(v)
  end
  return ret
end
utils.simple_copy_obj = simple_copy_obj

-- 随机一个字符串
local s = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
function utils.randomstring(range, n)
  if type(range) ~= "string" then
    n = range
    range = s
  end
  local r = rep(' ', n):gsub(".", function()
    local i = random(1, #range)
    return range:sub(i, i)
  end)
  return r
end

function utils.var_dump(data, max_level, prefix)
  if type(prefix) ~= "string" then
    prefix = ""
  end
  if type(data) ~= "table" then
    print(prefix .. tostring(data))
  else
    print(data)
    if max_level ~= 0 then
      local prefix_next = prefix .. "    "
      print(prefix .. "{")
      for k, v in pairs(data) do
        io.stdout:write(prefix_next .. k .. " = ")
        if type(v) ~= "table" or (type(max_level) == "number" and max_level <= 1) then
          print(v, ",")
        else
          if max_level == nil then
            utils.var_dump(v, nil, prefix_next)
          else
            utils.var_dump(v, max_level - 1, prefix_next)
          end
        end
      end
      print(prefix .. "}")
    end
  end
end

function utils.serialize_table(obj, lvl)
  local lua = {}
  local t = type(obj)
  if t == "number" then
    table_insert(lua, obj)
  elseif t == "boolean" then
    table_insert(lua, tostring(obj))
  elseif t == "string" then
    table_insert(lua, string_format("%q", obj))
  elseif t == "table" then
    lvl = lvl or 0
    local lvls = ('  '):rep(lvl)
    local lvls2 = ('  '):rep(lvl + 1)
    table_insert(lua, "{\n")
    for k, v in pairs(obj) do
      table_insert(lua, lvls2)
      table_insert(lua, "[")
      table_insert(lua, utils.serialize_table(k,lvl+1))
      table_insert(lua, "]=")
      table_insert(lua, utils.serialize_table(v,lvl+1))
      table_insert(lua, ",\n")
    end
    local metatable = getmetatable(obj)
    if metatable ~= nil and type(metatable.__index) == "table" then
      for k, v in pairs(metatable.__index) do
        table_insert(lua, "[")
        table_insert(lua, utils.serialize_table(k, lvl + 1))
        table_insert(lua, "]=")
        table_insert(lua, utils.serialize_table(v, lvl + 1))
        table_insert(lua, ",\n")
      end
    end
    table_insert(lua, lvls)
    table_insert(lua, "}")
  elseif t == "nil" then
    return nil
  else
    print("can not serialize a " .. t .. " type.")
  end
  return table_concat(lua, "")
end

--反序列化
function utils.unserialize_table(lua)
  local t = type(lua)
  if t == "nil" or lua == "" then
    return nil
  elseif t == "number" or t == "string" or t == "boolean" then
    lua = tostring(lua)
  else
    print("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = load(lua)
  if func == nil then
    return nil
  end
  return func()
end

-- 写文件
function utils.write_file(file_name, string)
  local f = assert(io.open(file_name, 'w'))
  f:write(string)
  f:close()
end

function utils.append_file(file_name, string)
  local f = assert(io.open(file_name, 'a+'))
  f:write(string)
  f:write("\n")
  f:close()
end

-- 二进制 转 十六进制 
local function bin2hexstr(s)  
    local str =string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)  
    return str  
end  

-- mongo bson字段_id可读格式
function utils.bsonId(_id)
  local id = bin2hexstr(string.sub(_id, 3))
  return id 
end

return utils
