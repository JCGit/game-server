local settings = {
  -- 网络配置
  hallName     = "hall",     -- 每个hall名字必须唯一
  console_host  = '127.0.0.1', -- implicit
  console_port  = 8010,

  gate_host     = '192.168.1.119',
  gate_port     = 8050,
  gate_max_client  = 40000,

  hash_shut_down = false,   -- 是否关闭hash检查

  --登陆认证服
  login_conf = {
    console_port        = 8011,
    login_port          = 8051,        -- 登陆认证端口
    login_slave_cout    = 2,           -- 登陆认证代理个数
  },

  --中心服
  center_conf = {
    console_port           = 8012,
  },
}

settings.redis_conf = {
  host = '127.0.0.1',
  port = 6379,
  db   = 1,
}

-- 日志级别
settings.log_level = {
  LOG_DEFAULT   = 1,
  LOG_TRACE     = 1,
  LOG_DEBUG     = 2,
  LOG_INFO      = 3,
  LOG_WARN      = 4,
  LOG_ERROR     = 5,
  LOG_FATAL     = 6,
}

settings.client_short_info = false  -- 记录发送个客户端的简短日志

return settings
