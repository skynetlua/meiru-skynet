local Com = include("com", ...)

local ComBody = class("ComBody", Com)

function ComBody:ctor()
end

function ComBody:match(req, res)
	local content_type = req.headers['content-type']
	if type(content_type) ~= 'string' then
		return
	end
	local ret = content_type:find('application/x-www-form-urlencoded', 1, true)
	if ret and type(req.rawbody) == 'string' then
		local tmp = req.rawbody:urldecode()
		local items = tmp:split("&")
		local body = {}
		for _,item in ipairs(items) do
			tmp = item:split("=")
			body[tmp[1]] = tmp[2] or ""
		end
		req.body = body
	end
end


return ComBody
