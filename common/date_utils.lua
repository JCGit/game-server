local os_date = os.date
local os_time = os.time

local utils = {}

local DAY_SECOND = 24 * 60 * 60

function utils.day_internal(a, b)
  a = utils.dayBeginTime(a)
  b = utils.dayBeginTime(b)
  return (a - b) // DAY_SECOND
end

function utils.dayBeginTime(a)
  local t = os_date("*t", a)
  t.hour = 0
  t.min = 0
  t.sec = 0
  return os_time(t)
end

return utils
