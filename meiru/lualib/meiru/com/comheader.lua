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
end

return ComHeader
