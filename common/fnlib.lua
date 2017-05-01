local fnlib = {}

local table  = table
local pairs  = pairs
local ipairs = ipairs

function fnlib.empty_table(tb)
  for k, v in pairs(tb) do
    tb[k] = nil
  end
end

function fnlib.array_foreach(tb, f, ...)
  for i = 1, #tb do
    f(tb[i], i, ...)
  end
end

function fnlib.foreach_kv(tb, f, ...)
  for k, v in pairs(tb) do
    f(k, v, ...)
  end
end

function fnlib.foreach_v(tb, f, ...)
  for _, v in pairs(tb) do
    f(v, ...)
  end
end

function fnlib.dict_size(tb)
  local n = 0
  for k, v in pairs(tb) do
    n = n + 1
  end
  return n
end

function fnlib.elem(array, e)
  for i = 1, #array do
    if e == array[i] then
      return true
    end
  end
  return false
end

function fnlib.spairs(t, cmp)
  local sort_keys = {}
  for k, v in pairs(t) do
    table.insert(sort_keys, {k, v})
  end
  local sf
  if cmp then
    sf = function (a, b) return cmp(a[1], b[1]) end
  else
    sf = function (a, b) return a[1] < b[1] end
  end
  table.sort(sort_keys, sf)

  return function (tb, index)
    local ni, v = next(tb, index)
    if ni then
      return ni, v[1], v[2]
    else
      return ni
    end
  end, sort_keys, nil
end

function printf(fmt, ...)
  if type(fmt) == 'string' then
    print(fmt:format(...))
  else
    print(fmt, ...)
  end
end

_ENV.fnlib = fnlib

return fnlib
