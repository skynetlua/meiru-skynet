local Com = include("com", ...)

----------------------------------------------
--ComResponse
----------------------------------------------
local ComResponse = class("ComResponse", Com)

function ComResponse:ctor()
end

function ComResponse:match(req, res)
	if res.req_ret == true then
		res.app.response(res, res.get_statuscode(), res.get_body(), res.get_headers())
		return true
	elseif res.req_ret == false then
		log("dispatch failed")
	else
		log("dispatch nothing")
		assert(not res.is_end)
	end
	res.app.response(res, 404, "HelloWorld404")
	return true
end

return ComResponse
