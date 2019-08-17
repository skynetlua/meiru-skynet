local Com = include("com", ...)

local ComCors = class("ComCors", Com)

--跨域限制
----------------------------------------------
--ComCors
----------------------------------------------
function ComCors:ctor()
end

function ComCors:match(req, res)
	local app = req.app
	if app.get('host') then
		local host = header['host']
		if not host then
			return false
		end
		local idx = host:find(":", 1, true)
		if idx then
			host = host:sub(1, idx-1)
		end
		if app.get('host') ~= host then
			assert(false)
			return false
		end
	end
end

return ComCors
