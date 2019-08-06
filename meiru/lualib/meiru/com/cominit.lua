local Com = include("com", ...)

local ComInit = class("ComInit", Com)

function ComInit:ctor()
end

function ComInit:match(req, res)
	if req.app.get('x-powered-by') then
		res.set_header('X-Powered-By', 'MeiRu')
	end
	res.set_header('server', 'MeiRu/1.0.0')
	res.set_header('accept-ranges', 'bytes')
end

return ComInit
