local skynet = require 'skynet'
local queue = require 'skynet.queue'

local sharedata = require 'sharedata'

local M = {}

-- 本服务缓存的 sharedata配置
local cached_configs = {}

local query_queue = queue()

--- 去掉运行时动态增加新配置项
-- 所有有效的配置项启动的时候创建后，运行时只可以动态更新
-- 如有需要可以新增增加配置项的接口
function M.get_config(config_name)
  local cc = cached_configs[config_name]
  if not cc then
    query_queue(function ()
      if not cached_configs[config_name] then
        cached_configs[config_name] = sharedata.query(config_name)
      end
    end)
    cc = assert(cached_configs[config_name])
  end
  return cc
end

return M
