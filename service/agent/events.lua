local M = {}


-- 通过认证
M.player_login = 'player_login'

-- 超时或其他原因登出，多重登录时被登出
M.player_logout = 'player_logout'

-- 用户登录服务器时初始化用户数据
M.player_online = 'player_online'

-- 玩家下线
M.player_offline = 'player_offline'

-- 用户属性更新
M.profile_update = 'profile_update'


return M
