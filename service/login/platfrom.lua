local constant = require "constant"
local redisx   = require "redisx"
require "logger_api"()

local M = {}

local function check_since_test()
    return true
end

local function check_self_operate(pf, username, pass)
  -- local validpass = redisx.hgetstring(constant.user_password_key, username)
  -- return validpass == pass
  return true
end

M.platfrom_permission_check = {
    inner    = check_since_test,
    inner2   = check_self_operate,
}

return M
