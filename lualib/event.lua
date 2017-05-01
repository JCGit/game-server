--- Event使用说明：
-- 在一个服务（虚拟机）内使用
-- 不同的事件通过 事件名 来唯一区分
--
-- 产生事件源的位置：
-- * Event.dispatchEvent('eventName', ...)
--
-- 处理事件的模块使用下面的方法来添加监听事件:
-- * Event.addEventListener('eventName', function (eventName, ...) end, tag)
--
-- 取消事件监听:
-- * removeEventListener 参数是handle, 添加时的返回值
-- * removeEventListenersByTag
-- * removeEventListenersByEvent
--
-- 判断是否已经监听某事件使用
-- * hasEventListener
--
-- @module agent.event

local Event = {}

local string_upper, table_insert, table_sort = string.upper, table.insert, table.sort
local assert, tostring, pairs, type, ipairs = assert, tostring, pairs, type, ipairs

local listeners_ = {}

local function check_event_name(en)
  assert(type(en) == "string" and en ~= "", "bad eventName argument")
end

function Event.addEventListener(eventName, listener, order, tag)
  check_event_name(eventName)
  assert(type(listener) == 'function', 'bad argument!')

  eventName = string_upper(eventName)
  if listeners_[eventName] == nil then
    listeners_[eventName] = {}
  end

  if not order then order = 0 end
  table_insert(listeners_[eventName], { listener, tag, order = order})
  table_sort(listeners_[eventName], function (a, b) return a.order < b.order end)

  return handle
end

function Event.dispatchEvent(eventName, ...)
  check_event_name(eventName)
  local obj = listeners_[string_upper(eventName)]
  if obj then
    for _, listener in ipairs(obj) do
      listener[1](eventName, ...) -- 这里也可以使用pcall，容错性高一些
    end
  end
end

function Event.removeEventListener(handleToRemove, eventName)
  if eventName then
    check_event_name(eventName)
    local listenersForEvent = listeners_[string_upper(eventName)]
    if listenersForEvent[handleToRemove] then
      listenersForEvent[handleToRemove] = nil
      return true
    end
  end
  for _, listenersForEvent in pairs(listeners_) do
    if listenersForEvent[handleToRemove] then
      listenersForEvent[handleToRemove] = nil
      return true
    end
  end
  return false
end

function Event.removeEventListenersByTag(tagToRemove)
  assert(tagToRemove, 'nil tag argument')
  for eventName, listenersForEvent in pairs(listeners_) do
    for handle, listener in ipairs(listenersForEvent) do
      if listener[2] == tagToRemove then
        listenersForEvent[handle] = nil
      end
    end
  end
end

function Event.removeEventListenersByEvent(eventName)
  check_event_name(eventName)
  listeners_[string_upper(eventName)] = nil
end

function Event.removeAllEventListeners()
  listeners_ = {}
end

function Event.hasEventListener(eventName)
  check_event_name(eventName)

  local l = listeners_[string_upper(eventName)]
  if l == nil then
    return false
  end
  return next(l) and true or false
end

function Event.dumpAllEventListeners()
  local r = {}
  for name, listeners in pairs(listeners_) do
    table.insert(r, 'event: ' .. name)
    for handle, listener in ipairs(listeners) do
      table.insert('  listener, handle: ' .. listener[1] .. handle)
    end
  end
  return table.concat(r, '\n')
end

return Event
