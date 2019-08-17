local Com = include("com", ...)

----------------------------------------------
--ComHeader
----------------------------------------------
local ComHeader = class("ComHeader", Com)

function ComHeader:ctor()

end

function ComHeader:match(req, res)
	local header = {}
	for k,v in pairs(req.rawheader) do
		k = string.lower(k)
		if k == 'user-agent' or k == 'content-type' then
			v = string.lower(v)
		end
		header[k] = v
	end
	req.header = header
end

return ComHeader
