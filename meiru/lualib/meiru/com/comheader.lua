local Com = include("com", ...)

local ComHeader = class("ComHeader", Com)

function ComHeader:ctor()

end

function ComHeader:match(req, res)
	local headers = {}
	for k,v in pairs(req.rawheaders) do
		k = string.lower(k)
		if k == 'user-agent' or k == 'content-type' then
			v = string.lower(v)
		end
		headers[k] = v
	end
	req.headers = headers
	local app = req.app
	if app.get('host') then
		local host = headers['host']
		if not host then
			return false
		end
		local idx = string.find(host, ":", 1, true)
		if idx then
			host = string.sub(host, 1, idx-1)
		end
		if app.get('host') ~= host then
			assert(false)
			return false
		end
	end
end

return ComHeader
