
local Com = include("com", ...)
local url = include(".util.url", ...)

----------------------------------------------
--ComPath
----------------------------------------------
local ComPath = class("ComPath", Com)

function ComPath:ctor()
end

function ComPath:match(req, res)
    req.path, req.query = url.parse_url(req.rawurl)
    local idx = req.path:find("/", 1, true)
    if idx ~= 1 then
		return false
	end
    if req.query then
        req.query = url.parse_query(req.query)
    else
    	req.query = {}
    end
    req.path_params = req.path:split("/")
end

return ComPath
