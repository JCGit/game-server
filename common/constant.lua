local M = {}

M.platfrom_type = {
  [1010] = "inner",
  [100]  = "inner2",         -- 自主运营
}

M.uin_min_value = 10000000

M.uin_info_key      = "account:uin_info"
M.user_password_key = "account:user_password"

M.gm_appoint = {
	to_agent = 1,
	to_all 	 = 2,
}

M.gm_resp_type =
{
    success            = {0, "success"},      
    sign_failed        = {1, "校验签名失败"},       
    params_failed      = {2, "缺少参数"},     
    method_not_found   = {3, "方法不存在"}, 	
    user_not_found     = {4, "该用户不存在"},    
    call_failed        = {5, "调用失败"},    
}

function M.genGmResp(type, content)
	local resp = {
		status = type[1],
		msg = type[2],
	}

	if content then
		resp.content = content
	end

	return resp
end

return M
